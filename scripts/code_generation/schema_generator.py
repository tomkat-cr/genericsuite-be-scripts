"""
schema_files_generator.py
2024-10-27 | CR
"""
import time
import os
from datetime import datetime
import requests

import json
import argparse
import pprint

import ollama
from ollama import Client

from openai import OpenAI

DEBUG = True
USE_PPRINT = False

DEFAULT_AI_PROVIDER = "nvidia"
# DEFAULT_AI_PROVIDER = "chat_openai"
# DEFAULT_AI_PROVIDER = "ollama"

DEFAULT_MODEL_TO_USE = ""
# DEFAULT_MODEL_TO_USE = "nvidia/llama-3.1-nemotron-70b-instruct"
# DEFAULT_MODEL_TO_USE = "nemotron"
# DEFAULT_MODEL_TO_USE = "llava"
# DEFAULT_MODEL_TO_USE = "llama3.2"

OLLAMA_BASE_URL = ""
# OLLAMA_BASE_URL = "localhost:11434"
OLLAMA_TEMPERATURE = ""
OLLAMA_STREAM = ""

AGENTS_COUNT = 0


# Default prompt to generate the .json files for the frontend and backend
DEFAULT_PROMPT = """
You are a developer specialized in JSON files generation.
Your task is to create the JSON files for the frontend and backend
of the given application.
"""
USER_MESSAGE_PROMPT = """
The given application and its schema/table descriptions are described below:
----------------
{user_input}
----------------
Based on the following documentation and examples:
{files}
Give me ONLY the generic CRUD editor configuration JSON files for
the given application.
The JSON files must be build according to the specifications and instructions
in the `Generic-CRUD-Editor-Configuration.md` file.
The JSON example files: `frontend/users.json`, `frontend/users_config.json`,
`backend/users.json`, and `backend/users_config.json` are included only as
a reference.
Don't give recommendations, observations, or explanations, just
give me the JSON files names and content for the given application
(not the JSON example files).
"""


class JsonGenerator:
    """
    Class to generate the .json files for the frontend and backend
    """

    def __init__(self):

        self.args = self.read_arguments()
        self.reference_files = self.get_reference_files()
        self.prompt = DEFAULT_PROMPT
        self.user_input = USER_MESSAGE_PROMPT.format(
            user_input=self.read_user_input(),
            files="\n".join([
                f"\nFile: {f.get('name')}" +
                "\nFile content:" +
                "\n-----------------" +
                f"\n{f.get('content')}" +
                "\n-----------------"
                for f in self.reference_files
            ]),
        )
        self.final_input = None
        self.final_summary = None

    def read_arguments(self):
        """
        Read arguments from the command line
        """
        parser = argparse.ArgumentParser()
        parser.add_argument(
            '--user_input',
            type=str,
            default=None,
            help='User input file to be used as the initial plan. ' +
                 'It\'s mandatory to provide a user input file.'
        )
        parser.add_argument(
            '--provider',
            type=str,
            default=DEFAULT_AI_PROVIDER,
            help='Provider to use (ollama, nvidia, chat_openai). ' +
            f'Default: {DEFAULT_MODEL_TO_USE}'
        )
        parser.add_argument(
            '--model',
            type=str,
            default=DEFAULT_MODEL_TO_USE,
            help=f'Model to use. Default: {DEFAULT_MODEL_TO_USE}'
        )
        parser.add_argument(
            '--temperature',
            type=str,
            default=OLLAMA_TEMPERATURE,
            help=f'Temperature to use. Default: {0.5}'
        )
        parser.add_argument(
            '--stream',
            type=str,
            default=OLLAMA_STREAM,
            help=f'Stream to use. Default: {"1"}'
        )
        parser.add_argument(
            '--agents_count',
            type=int,
            default=AGENTS_COUNT,
            help=f'Number of agents to use. Default: {AGENTS_COUNT}'
        )
        parser.add_argument(
            '--ollama_base_url',
            type=str,
            default=OLLAMA_BASE_URL,
            help=f'Ollama base URL. Default: {OLLAMA_BASE_URL}'
        )

        args = parser.parse_args()
        return args

    def read_user_input(self):
        """
        Read the user input from a file
        """
        if self.args.user_input is None:
            raise ValueError("User input file is mandatory")

        if not os.path.exists(self.args.user_input):
            raise FileNotFoundError(
                f"User input file not found: {self.args.user_input}")

        with open(self.args.user_input, 'r') as f:
            user_input = f.read()

        return user_input

    def log_debug(self, message):
        """
        Prints the message for debugging
        """
        if DEBUG:
            print(message)

    def log_debug_structured(self, messages):
        """
        Prints the messages in a structured way for debugging
        """
        if DEBUG:
            if USE_PPRINT:
                pp = pprint.PrettyPrinter(indent=4)
                pp.pprint(messages)
                print("")
            else:
                print(messages)

    def get_elapsed_time_formatted(self, elapsed_time):
        """
        Returns the elapsed time formatted
        """
        if elapsed_time < 60:
            return f"{elapsed_time:.2f} seconds"
        elif elapsed_time < 3600:
            return f"{elapsed_time / 60:.2f} minutes"
        else:
            return f"{elapsed_time / 3600:.2f} hours"

    def log_procesing_time(self, message: str = "", start_time: float = None):
        """
        Returns the current time and prints the message
        """
        if start_time is None:
            start_time = time.time()
            readable_timestamp = datetime.fromtimestamp(start_time) \
                .strftime('%Y-%m-%d %H:%M:%S')
            print("")
            print((message if message else 'Process') +
                  f" started at {readable_timestamp}...")
            return start_time

        end_time = time.time()

        readable_timestamp = datetime.fromtimestamp(end_time) \
            .strftime('%Y-%m-%d %H:%M:%S')
        processing_time = self.get_elapsed_time_formatted(
            end_time - start_time)

        print("")
        print(
            (message if message else 'Process') +
            f" ended at {readable_timestamp}" +
            f". Processing time: {processing_time}")
        return end_time

    def get_model(self, model_to_use: str = None):
        """
        Returns the model to use based on the default model to use
        """
        if not model_to_use:
            model_to_use = self.args.model
        return model_to_use

    def unify_messages(self, messages):
        """
        Unifies the messages to be compatible with the different providers
        """
        # Both system and user must be unified in one user message
        return [{
            "role": "user",
            "content": "\n".join([m["content"] for m in messages])
        }]

    def fix_messages(self, messages):
        """
        Fixes the messages to be compatible with the different providers
        """
        if self.args.provider == "nvidia":
            return self.unify_messages(messages)
        return messages

    def get_model_response(self, model: str, messages: list):
        """
        Returns the response from the model
        """
        model_config = {
            'messages': self.fix_messages(messages),
            'model': model,
        }

        if self.args.temperature:
            if self.args.provider == "ollama":
                model_config['options'] = {
                    "temperature": float(self.args.temperature)
                }
            else:
                model_config['temperature'] = float(self.args.temperature)
        elif self.args.provider == "nvidia":
            model_config['temperature'] = 0.5

        if self.args.stream:
            model_config['stream'] = self.args.stream == "1"
        if self.args.provider == "nvidia":
            model_config['stream'] = True

        # Reference:
        # https://pypi.org/project/ollama/
        # https://github.com/ollama/ollama/blob/main/docs/api.md
        #
        self.log_debug("")
        self.log_debug(f"Provider: {self.args.provider}" +
                       f" | Model: {model_config['model']}")
        # self.log_debug_structured(model_config)

        if self.args.provider == "ollama":
            if self.args.ollama_base_url:
                self.log_debug(
                    "Using ollama client with base_url:" +
                    f" {self.args.ollama_base_url}")
                self.log_debug("")
                client = Client(host=self.args.ollama_base_url)
                response_raw = client.chat(**model_config)
            else:
                response_raw = ollama.chat(**model_config)
            response = response_raw['message']['content']

        elif self.args.provider == "nvidia":
            client = OpenAI(
                base_url="https://integrate.api.nvidia.com/v1",
                api_key=os.environ.get("NVIDIA_API_KEY"),
            )
            completion = client.chat.completions.create(
                top_p=1,
                # max_tokens=1024,
                **model_config
            )
            response = ""
            for chunk in completion:
                if chunk.choices[0].delta.content is not None:
                    print(chunk.choices[0].delta.content, end="")
                    response += chunk.choices[0].delta.content

        elif self.args.provider == "chat_openai":
            client = OpenAI(
                api_key=os.environ.get("OPENAI_API_KEY"),
            )
            response_raw = client.chat.completions.create(
                top_p=1,
                **model_config
            )
            response = response_raw.choices[0].message.content
        else:
            raise ValueError(f"Invalid provider: {self.args.provider}")

        self.log_debug("")
        self.log_debug(f'Response: {response}')

        return response

    def CEO_Agent(self, user_input, is_final=False):
        """
        Main agent that creates initial plan and final summary
        """
        system_prompt = 'You are o1, an AI assistant focused on clear ' + \
            'step-by-step reasoning. Break every task into ' + \
            f'{self.args.agents_count} actionable step(s). ' + \
            'Always answer in short.' \
            if not is_final else \
            'Summarize the following plan and its implementation into a ' + \
            'cohesive final strategy.'

        messages = [
            {
                'role': 'system',
                'content': system_prompt
            },
            {
                'role': 'user',
                'content': user_input
            }
        ]

        self.log_debug("")
        self.log_debug(f"CEO messages (is_final: {is_final}):")
        self.log_debug_structured(messages)

        start_time = self.log_procesing_time(
            f'CEO {"final" if is_final else "initial"} processing...')

        response = self.get_model_response(
            model=self.get_model(),
            messages=messages
        )

        self.log_procesing_time(start_time=start_time)
        self.log_debug("")
        self.log_debug(f'CEO {"final" if is_final else "initial"} response:')
        self.log_debug(response)

        return response

    def create_agent(self, step_number):
        """
        Factory method to create specialized agents for each step
        """
        def agent(task):
            messages = [
                {
                    'role': 'system',
                    'content': f'You are Agent {step_number}, focused ONLY ' +
                    f'on implementing step {step_number}. Provide a detailed' +
                    ' but concise implementation of this specific step. ' +
                    'Ignore all other steps.'
                },
                {
                    'role': 'user',
                    'content': f'Given this task:\n{task}\n\nProvide ' +
                    f'implementation for step {step_number} only'
                }
            ]
            self.log_debug("")
            self.log_debug(f'Agent step-{step_number} messages:')
            self.log_debug_structured(messages)

            start_time = self.log_procesing_time(f"Agent step-{step_number}")
            response = self.get_model_response(
                model=self.get_model(),
                messages=messages
            )

            self.log_procesing_time(
                message=f"Agent step-{step_number}",
                start_time=start_time)
            self.log_debug("")
            self.log_debug(f'Agent step-{step_number} response:')
            self.log_debug(response)

            return response

        return agent

    def read_file(self, file_path):
        """
        Reads a file and returns its content
        """
        # If the file path begins with "http", it's a URL
        if file_path.startswith("http"):
            # If the file path begins with "https://github.com",
            # we need to replace it with "https://raw.githubusercontent.com"
            # to get the raw content
            if file_path.startswith("https://github.com"):
                file_path = file_path.replace(
                    "https://github.com",
                    "https://raw.githubusercontent.com")
                file_path = file_path.replace("blob/", "")
            response = requests.get(file_path)
            if response.status_code == 200:
                content = response.text
            else:
                raise ValueError(f"Error reading file: {file_path}")
        else:
            with open(file_path, 'r') as f:
                content = f.read()
        return content

    def get_reference_files(self):
        """
        Returns the reference files to be used
        """
        # Read the `schema_generator_ref_files.json` file
        with open('schema_generator_ref_files.json', 'r') as f:
            ref_files = json.load(f)

        # Create a list of dictionaries with the name, path and content of each
        # reference file
        ref_files_list = [
            {
                'name': ref_file['name'],
                'path': ref_file['path'],
                'content': self.read_file(ref_file['path']),
            } for ref_file in ref_files
        ]
        return ref_files_list

    def save_result(self):
        """
        Saves the final result to a file
        """
        with open('final_summary.txt', 'w') as f:
            if DEBUG:
                f.write("DEBUG Prompt:\n")
                f.write("\n")
                f.write(self.prompt)
                f.write("\n")
            f.write("\n")
            f.write("User input:\n")
            f.write("\n")
            f.write(self.user_input)
            f.write("\n")
            if self.final_input:
                f.write("\n")
                f.write("Final input:\n")
                f.write("\n")
                f.write(self.final_input)
                f.write("\n")
            f.write("\n")
            f.write(">>> Final summary:\n")
            f.write("\n")
            f.write(self.final_summary)
            f.write("\n")

    def process_task(self):
        """
        Orchestrate the entire workflow to get the final summary
        """
        start_time = self.log_procesing_time(
            "Main process" +
            f"{self.args.agents_count} agent steps...")

        # Step # 1: Get high level plan from CEO
        initial_plan = self.CEO_Agent(f'{self.prompt}\n{self.user_input}')

        # Step # 2: Create agents, execute all agent steps, and get detailed
        # implementation for each step
        agents = [self.create_agent(i)
                  for i in range(1, self.args.agents_count + 1)]
        implementations = [agent(initial_plan) for agent in agents]

        # Step # 3: Combine everything to get the final summary from CEO
        self.final_input = \
            f"Initial Plan:\n{initial_plan}" + \
            "\n\nImplementations: \n" + \
            "\n".join(implementations)

        # Step # 4: Final summary
        self.final_summary = self.CEO_Agent(self.final_input, is_final=True)

        # Save everything to a file
        self.save_result()

        self.log_procesing_time(message="Main process", start_time=start_time)
        return self.final_summary

    def simple_processing(self):
        """
        Simple processing without agents
        """
        messages = [
            {
                'role': 'system',
                'content': self.prompt
            },
            {
                'role': 'user',
                'content': self.user_input
            }
        ]

        self.log_debug("")
        self.log_debug("Simple Processing messages:")
        self.log_debug_structured(messages)

        start_time = self.log_procesing_time('Simple Processing...')

        response = self.get_model_response(
            model=self.get_model(),
            messages=messages
        )

        self.log_procesing_time(start_time=start_time)
        self.log_debug("")
        self.log_debug('Simple Processing response:')
        self.log_debug(response)

        self.final_summary = response
        self.save_result()
        return self.final_summary

    def generate_json(self):
        """
        Main entry point to generate the .json files
        """
        if self.args.agents_count == 0:
            # If the number of agents is 0, we don't need to use the agents
            return self.simple_processing()
        else:
            # Reasoning with agents
            return self.process_task()


if __name__ == "__main__":

    json_generator = JsonGenerator()
    final_result = json_generator.generate_json()

    print("")
    print("Final result:")
    print(final_result)
    print("")
