using System;
using System.Collections.Generic;
using System.Net.Sockets;
using Thrift;
using Thrift.Protocol;
using Thrift.Transport;

namespace FXBusinessLogic.BusinessObjects.Thrift
{
    public class FXMindMQLClient : FXMindMQL.Iface //<Base>  where Base : new (Thrift.Protocol.TProtocol p) 
    {
        protected TTransport transport;
        protected TProtocol protocol;
        protected FXMindMQL.Client client;
        public FXMindMQLClient(string host, ushort port)
        {
            try
            {
                transport = new TSocket(host, port);
                //transport = new TFramedTransport(new TSocket(host, port));

                protocol = new TBinaryProtocol(transport);
                client = new FXMindMQL.Client(protocol);
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

        public List<string> ProcessStringData(Dictionary<string, string> paramsList, List<string> inputData)
        {
            List<string> list = new List<string>();
            transport.Open();
            try
            {
                list = client.ProcessStringData(paramsList, inputData);
            }
            finally
            {
                transport.Close();
            }
            return list;
        }

        public List<double> ProcessDoubleData(Dictionary<string, string> paramsList, List<string> inputData)
        {
            List<double> list = new List<double>();
            transport.Open();
            try
            {
                list = client.ProcessDoubleData(paramsList, inputData);
            }
            finally
            {
                transport.Close();
            }
            return list;
        }

        public long IsServerActive(Dictionary<string, string> paramsList)
        {
            transport.Open();
            long retval = 0;
            try
            {
                retval = client.IsServerActive(paramsList);
            }
            finally
            {
                transport.Close();
            }
            return retval;
        }

        public void PostStatusMessage(Dictionary<string, string> paramsList)
        {
            transport.Open();
            try
            {
                client.PostStatusMessage(paramsList);
            }
            finally
            {
                transport.Close();
            }
        }

        public void Dispose()
        {
            client.Dispose();
        }
    }
}
