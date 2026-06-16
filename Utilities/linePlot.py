from fastmcp import FastMCP
from fastmcp.utilities.types import Image

import csv
from typing import Tuple
from typing import List

import matplotlib.pyplot as plt
import numpy as np

import os
import re
import argparse
import logging

mcp = FastMCP(name="LinePlot", stateless_http=True)

@mcp.tool
def linePlot(csv_file,jpg_file) -> Tuple[bool,str]:
    """Generate a line graph from the data in a CSV file and save the graph as a JPG file"""
    
      # Open the CSV file in read mode ('r')
    with open(csv_file, 'r') as file:
        # Create a csv.reader object
        csv_reader = csv.reader(file)

        # Optionally, skip the header row if present
        #header = next(csv_reader) # Reads the first row (header)

        # Iterate over each row in the CSV file
        result = []
        for row in csv_reader:
            result.append(row[0])
        y_list = ','.join(result)
        
    y_list = [float(item) for item in y_list.split(',')]
    y = np.array(y_list)
    x = np.array(range(0,len(y_list)))
    plt.plot(x,y)
    plt.savefig(jpg_file,dpi=300)
    status = True
    msg = 'OK'
    return status,msg
   
    
def main():
    parser = argparse.ArgumentParser(description="MCP server of many talents.")
    parser.add_argument("--port", type=int, help="Server will listen on localhost:<port>.")
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
    
    # If there is a port argument, start as HTTP. Otherwise, STDIO.
    if args.port:
        mcp.run( transport="http", port=args.port, host="localhost")
    else:
        mcp.run()
    
    
if __name__ == "__main__":
    main()

	