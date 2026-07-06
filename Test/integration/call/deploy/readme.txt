orderMatters for MATLAB Production Server

Before you can use the functions packaged by the compiler, you need to do the following:
* Deploy orderMatters.ctf to a server instance
* Develop a client application to access the functions.

1. Deploy orderMatters.ctf

1.1 Prerequisites to Deployment
Before you can deploy orderMatters.ctf, you need a server instance to host it. The server 
instance must be configured to have access to MATLAB Runtime(R2026b).
* If you do not have a server instance created, see: 
  https://www.mathworks.com/help/mps/server/creating-a-server.html
* If you do not have MATLAB Runtime(R2026b) installed, download the installer from the 
  MATLAB Runtime page at: https://www.mathworks.com/products/compiler/mcr/index.html
* If you need to configure the server instance to use MATLAB Runtime(R2026b), see: 
  https://www.mathworks.com/help/mps/server/customize-the-configuration-file.html

1.2 orderMatters.ctf Deployment
To deploy orderMatters.ctf, copy it into the server instance's `auto_deploy` folder. The 
server instance will automatically deploy it and make it available to interested clients.

2. Develop Client Applications
MATLAB Production Server officially supports the following clients:
* C/C++: https://www.mathworks.com/help/mps/cxx-client-programming.html
* .NET: https://www.mathworks.com/help/mps/dotnet-client-programming.html
* Java: https://www.mathworks.com/help/mps/java-client-programming.html
* Python: https://www.mathworks.com/help/mps/python-client-programming.html

2.1 C/C++ 
The C/C++ client libraries are located in a platform specific folder at `MPS_INSTALL/client/c`.
The header files are located in `MPS_INSTALL/client/c/include`.
For information about developing C/C++ clients, see: 
* https://www.mathworks.com/help/mps/cxx-client-programming.html
* example code at `MPS_INSTALL/client/c/examples' 
* included C/C++ client documentation at `MPS_INSTALL/client/c/doc/index.html'

2.2 .NET
The .NET client libraries are located at 
`MPS_INSTALL/client/dotnet/MathWorks.MATLAB.ProductionServer.Client.dll`.
For information about developing .NET clients, see:
* https://www.mathworks.com/help/mps/dotnet-client-programming.html
* example code at `MPS_INSTALL/client/dotnet/examples'
* included .NET client documentation at 
`MPS_INSTALL/client/dotnet/doc/MathWorks.MATLAB.ProductionServer.Client.chm`

2.3 Java
The Java client libraries are located at `MPS_INSTALL/client/java/mps_client.jar`.
For information about developing Java clients, see:
* https://www.mathworks.com/help/mps/java-client-programming.html
* example code at `MPS_INSTALL/client/java/examples'
* included Javadoc at `MPS_INSTALL/client/java/doc/index.html`

2.4 Python 
The Python client package includes the following: 
* matlab - a set of classes for creating multi-dimensional MATLAB arrays 
* production_server - API for evaluating functions on a remote MATLAB Production Server 
  instance

The Python client installer is located in `MPS_INSTALL/client/python`. To install the 
client, go to that folder and execute:
 
python -m pip install .

For information about developing Python clients, see: 
* https://www.mathworks.com/help/mps/python-client-programming.html
* example code at `MPS_INSTALL/client/python/examples'
