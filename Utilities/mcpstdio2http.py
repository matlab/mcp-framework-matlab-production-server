# mcpstdio2http.py

# Copyright 2025, The MathWorks, Inc.

import os
import re
import sys
import logging
import requests
import argparse

def nospace(text):
    # Remove non-quoted whitespace.
    
    # Pattern matches either a quoted string or whitespace outside of quotes.
    # Two patterns: group 0 (quoted string), group 1 (whitespace)
    regex = re.compile(r'"[^"]*"|(\s+)')

    def replacement_function(match):
        # If group 1 (whitespace) exists, replace it with an empty string
        if match.group(1):
            return ""
        # Otherwise, return the original match (a quoted string)
        else:
            return match.group(0)

    return regex.sub(replacement_function, text)

def main():
    
    parser = argparse.ArgumentParser(
        description="Model Context Protocol STDIO -> HTTP proxy for MATLAB Production Server.")
    parser.add_argument("--url", type=str, default="http://localhost:9910/mcp", help="MCP endpoint on MATLAB Production Server")
    parser.add_argument("--timeout", type=int, default=30, help="HTTP request timeout in seconds.")
    parser.add_argument("--log-level", type=str, default=logging.INFO, help="Detail of messages in log file.")
    parser.add_argument("--log-file", type=str, default=os.path.basename(__file__)+".log", help="Name of log file.")
    parser.add_argument("--log-dir", type=str, default=os.getcwd(), help="Directory for storing log files.")

    args = parser.parse_args()
    
    logger = logging.getLogger(__name__)
    log_file = os.path.join(args.log_dir, args.log_file)
    file_handler = logging.FileHandler(log_file)
    formatter = logging.Formatter(fmt="{asctime} - {levelname} - {message}",style="{")
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)

    logger.setLevel(args.log_level)

    stdin = sys.stdin
    stdout = sys.stdout
    
    sys.stdout.reconfigure(encoding='utf-8')

    while True:
        # Every message must be a single line. It must end with a newline.
        payload = stdin.readline()
        logger.debug(f"Payload: ***{payload}***")
        if payload == "\n":
            continue

        # Forward to HTTP MCP server
        try:
            resp = requests.post(
                args.url,
                data=payload,
                headers={'Content-Type': 'application/json'},
                timeout=args.timeout,
            )
            resp.raise_for_status()
            logger.debug(f"Response: ***{resp}***") 
            
            # We'll just pass through the response as-is.
            
            resp_bytes = resp.content
            resp = resp_bytes.decode('UTF-8')
 
            # stdio protocol requires reponse on a single line.
            resp = nospace(resp.replace("\n", " "))+"\n"
            
            logger.debug(f"Content: ***{resp}***")
            
            # If the server data is empty after processing, 
            # emit no response, not even a newline.
            if len(resp) > 1:
                stdout.write(resp)
                stdout.flush()
            else:
                logger.debug("No response sent")
            
        except Exception as e:
            err = str(e)
            logger.error(f"Error proxying MCP request: {err}\n")
            break

if __name__ == "__main__":
    main()
