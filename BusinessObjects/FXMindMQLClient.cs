using BusinessObjects;
using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Sockets;
using Thrift;
using Thrift.Protocol;
using Thrift.Transport;

namespace BusinessObjects
{

    public class FXMindMQLClient : ThriftClient<FXMindMQL.Client> 
    {

        public FXMindMQLClient(long port)
        {
            try
            {
                Host = "127.0.0.1";
                Port = (int)port;

                InitBase();

                //if (String.IsNullOrEmpty(ThriftCalls._FullFilePath))
                //    ThriftCalls.InitDLL(this);

            }
            catch (TApplicationException x)
            {
                Console.WriteLine(x.StackTrace);
            }
            catch (SocketException s)
            {
                Console.WriteLine(s.ToString());
            }
        }


        public override FXMindMQL.Client CreateClient(TProtocol p)
        {
            client = new FXMindMQL.Client(p);
            return client;
        }

    }
}