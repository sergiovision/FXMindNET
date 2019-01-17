XTrade is a good project for managing trading experience and personal capital state.
Project consists from Server XTradeServer app and XTrade Web App. XTrade Main Server is a Windows service which manages all trading terminals, process all data and signals, stores everything in MySQL database, hosts XTrade Web app as a self host. 
XTrade Web App is an Angular Web application which administrates XTrade Server.

How to build server application:
1. Clone this repository
2. Run from command line: build.bat

To make build succeeded the following apps should be installed: Visual Studio 2017, Visual Studio 2017 Build tools.
Applications need to be installed to run server properly: 

1. MySQL Server version 5 or later.
2. Metatrader 5 Terminal
3. Optionally - QUIK terminal.
4. Optionally StockSharp applications in case if you trade with QUIK and/or Cryptos. StockSharp is free and can be downloaded here http://stocksharp.com.

MySQL database script located in /DB folder. Create database and name it “xtrade”. Run both sql scripts in DB folder.
Open Settings table and set the following variables

XTrade.TerminalUser - should be set to windows user login name where trading terminals will be running

XTrade.InstallDir - XTrade installation folder.

Metatrader.CommonFiles - path to MT5 common files folder

MQL.Sources - path to MQL folder where your MQL robots stored

Config /bin/XTrade.config file to point to your MySQL server db.

XTrade Server folders structure:

/bin - binary folder where server binaries stored.

/dist - location of XTeade WebApp production build files.

/BusinessLogic - main app logic

/BusinessObjects - shared business objects

/MainServer - main server self host and WebAPI controllers

/MQL - MQL sources of trading robot.

/QUIKConnector - connector library to QUIK terminal using StockSharp libraries.

/UnitTests - Tests of server WebAPI


***Warning***
It is a free version of application. Application works and can be used on real trading accounts. Although it is a free alfa version so it may contain bugs. You can base your trading software solutions on this app. If you need help with application installation/run/clarification on your trade server you can write me, but consultation is not free.

XTrade Web app repository and build instructions here https://github.com/sergiovision/XTradeWeb

