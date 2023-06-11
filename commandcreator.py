#!/usr/bin/env python3

"""
ChatGPT Command/Script Generator

This script takes a string as an argument and sends it to the ChatGPT API to generate a command or a script. The generated
command or script is printed to stdout. If no string is given as an argument, the user is prompted to enter one. The
OpenAI API key is retrieved from the shell variable $OPENAI_API_KEY or the user is prompted to enter it if not present.
The entered API key is stored for future use.

Author: Dennis Kelly Suchomsky
License: GPL-3.0
Date: June 2023
"""

import os
import openai
import sys
import platform

SUPPORTED_SHELLS = ["zsh", "bash", "sh"]
COMMAND_PROMPT_TEXT = "I want you to create a command from the text after \"Command:\", please only create and output the command nothing else."
SCRIPT_PROMPT_TEXT = "I want you to create a script from the text after \"Script:\", please only create and output the script nothing else.\n\nPlease provide a good filename for the script. You can use the following comment line: `#filename:your_script_name.sh`"


def prompt_api_key():
    """
    Prompt the user for the OpenAI API key and validate it.

    Returns:
        str: The validated API key.
    """
    api_key = os.environ.get("OPENAI_API_KEY")
    if api_key and validate_api_key(api_key):
        return api_key

    api_key = input("Please enter your OpenAI API key: ")
    if validate_api_key(api_key):
        os.environ["OPENAI_API_KEY"] = api_key
        return api_key
    else:
        print("Invalid API key. Please try again.")
        return prompt_api_key()


def validate_api_key(api_key):
    """
    Validate the provided OpenAI API key.

    Args:
        api_key (str): The OpenAI API key.

    Returns:
        bool: True if the API key is valid, False otherwise.
    """
    try:
        openai.api_key = api_key
        openai.Completion.create(engine="text-davinci-003", prompt="test", max_tokens=1)
        return True
    except Exception as e:
        print("An error occurred while validating the API key:", str(e))
        return False


def prompt_input_string():
    """
    Prompt the user to enter a string.

    Returns:
        str: The user-entered string.
    """
    input_string = input("Please enter a string: ")
    return input_string


def chat_with_gpt(shell, sys_info, input_string, prompt_text):
    """
    Communicate with the ChatGPT API to generate a command or script.

    Args:
        shell (str): The current shell.
        sys_info (str): System information.
        input_string (str): The user input string.
        prompt_text (str): The prompt text for the ChatGPT API.

    Returns:
        str: The generated command or script.
    """
    prompt = f"{prompt_text}\n\n```{shell}\n{sys_info}\n{input_string}\n```"
    try:
        response = openai.Completion.create(
            engine="text-davinci-003",
            prompt=prompt,
            max_tokens=1000,
            n=1,
            stop=None,
            temperature=0.7
        )
        return response.choices[0].text.strip()
    except Exception as e:
        print("An error occurred while communicating with the OpenAI API:", str(e))
        return None


def get_shell_info():
    """
    Get the current shell.

    Returns:
        str: The current shell.
    """
    shell = os.environ.get("SHELL")
    if shell and any(s in shell for s in SUPPORTED_SHELLS):
        return shell
    return "bash"


def get_sys_info():
    """
    Get the system information.

    Returns:
        str: The system information.
    """
    system = platform.system()
    release = platform.release()
    return f"Operating System: {system}, Release: {release}"


def generate_command(shell, sys_info, input_string):
    """
    Generate a command based on the input string.

    Args:
        shell (str): The current shell.
        sys_info (str): System information.
        input_string (str): The user input string.

    Returns:
        str: The generated command.
    """
    prompt_text = COMMAND_PROMPT_TEXT
    response = chat_with_gpt(shell, sys_info, input_string, prompt_text)
    return response


def generate_script(shell, sys_info, input_string):
    """
    Generate a script based on the input string.

    Args:
        shell (str): The current shell.
        sys_info (str): System information.
        input_string (str): The user input string.

    Returns:
        str: The generated script.
    """
    prompt_text = SCRIPT_PROMPT_TEXT
    response = chat_with_gpt(shell, sys_info, input_string, prompt_text)
    return response


def extract_filename_from_script(script_content):
    """
    Extract the filename from the script content.

    Args:
        script_content (str): The script content.

    Returns:
        str: The extracted filename or None if not found.
    """
    lines = script_content.splitlines()
    for line in lines:
        if line.startswith("#filename:"):
            filename = line.split(":")[1].strip()
            return filename
    return None


def save_script(filename, script_content):
    """
    Save the script to a file.

    Args:
        filename (str): The filename for the script.
        script_content (str): The script content.
    """
    try:
        with open(filename, "w") as file:
            file.write(script_content)
        os.chmod(filename, 0o755)
        print(f"Script saved as {filename}")
    except Exception as e:
        print("An error occurred while saving the script:", str(e))


def save_script_with_fallback(script_content):
    """
    Save the script with a fallback filename.

    Args:
        script_content (str): The script content.
    """
    fallback_filename = "script.sh"
    try:
        with open(fallback_filename, "w") as file:
            file.write(script_content)
        os.chmod(fallback_filename, 0o755)
        print(f"Script saved as {fallback_filename}")
    except Exception as e:
        print("An error occurred while saving the script:", str(e))


def main():
    api_key = prompt_api_key()
    openai.api_key = api_key

    if len(sys.argv) > 1:
        if sys.argv[1] == "-s":
            if len(sys.argv) > 2:
                input_string = " ".join(sys.argv[2:])
                shell = get_shell_info()
                sys_info = get_sys_info()
                script_content = generate_script(shell, sys_info, input_string)
                if script_content is not None:
                    filename = extract_filename_from_script(script_content)
                    if filename is None:
                        print("Filename not found in the script content. Saving with fallback filename.")
                        save_script_with_fallback(script_content)
                    else:
                        save_script(filename, script_content)
            else:
                print("Please provide a string to generate the script.")
        else:
            input_string = " ".join(sys.argv[1:])
            shell = get_shell_info()
            sys_info = get_sys_info()
            command = generate_command(shell, sys_info, input_string)
            if command is not None:
                print("Generated Command:")
                print(command)
    else:
        input_string = prompt_input_string()
        shell = get_shell_info()
        sys_info = get_sys_info()
        command = generate_command(shell, sys_info, input_string)
        if command is not None:
            print("Generated Command:")
            print(command)


if __name__ == "__main__":
    main()
