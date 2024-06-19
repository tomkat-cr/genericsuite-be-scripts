"""
generate_seed.py
2024-05-09 | CR

Reference:
https://stackoverflow.com/questions/53897333/read-fernet-key-causes-valueerror-fernet-key-must-be-32-url-safe-base64-encoded
"""
from cryptography.fernet import Fernet


def main():
    """
    Generate a new seed.
    """
    key = Fernet.generate_key()
    print("")
    print("..........")
    print("")
    print("New seed generated (to assign STORAGE_URL_SEED):")
    print(key)
    print("")
    print("..........")
    print("")


if __name__ == "__main__":
    main()
