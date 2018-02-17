﻿using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using FXBusinessLogic.BusinessObjects.Thrift;
using RGiesecke.DllExport;
namespace ThriftMQL
{
    public class ThriftCalls
    {
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        public struct THRIFT_CLIENT
        {
            public UInt16 port;
            public Int32 Magic;
            public Int32 accountNumber;
            public byte ip0;
            public byte ip1;
            public byte ip2;
            public byte ip3;
        }

        public static string HostFromClient(THRIFT_CLIENT tc)
        {
            return string.Format("{0}.{1}.{2}.{3}", tc.ip0, tc.ip1, tc.ip2, tc.ip3);
        }

        //public static string host = "127.0.0.1";

        protected static FXMindMQLClient client;

        protected static List<string> StringToList(string str)
        {
            List<string> list = new List<string>();
            if (str == null)
                return list;
            if (str.Length > 0)
            {
                string[] arr = str.Split(new[] { '|' });
                list = new List<string>(arr);
            }
            return list;
        }

        protected static bool ListToString(ref StringBuilder str, List<string> list )
        {
            //str.Clear();
            int i = 0;
            foreach (var val in list)
            {
                str.Append(val);
                if (i++ < (list.Count - 1))
                    str.Append('|');
            }
            return true;
        }
        protected static void FillParams(ref THRIFT_CLIENT tc, string parameters, Dictionary<string, string> paramsDic)
        {
            if (parameters.Length > 0)
            {
                string[] paramValues = parameters.Split(new[] { '|' });
                if (paramValues.Length > 1)
                {
                    foreach (var paramValue in paramValues)
                    {
                        string[] oneParamKeyValue = paramValue.Split(new[] { '=' });
                        if (oneParamKeyValue.Length == 2)
                        {
                            paramsDic[oneParamKeyValue[0]] = oneParamKeyValue[1];
                        }
                    }
                }
            }
            paramsDic["magic"] = tc.Magic.ToString();
            paramsDic["account"] = tc.accountNumber.ToString();
        }

        [DllExport("ProcessDoubleData", CallingConvention = CallingConvention.StdCall)]
        public static long ProcessDoubleData([In, Out, MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 1)]double[] arr, int arr_size,
            [MarshalAs(UnmanagedType.LPWStr)]string parameters, [MarshalAs(UnmanagedType.LPWStr)]string dataStr, ref THRIFT_CLIENT tc)
        {
            List<double> resDblList = null;
            try
            {
                if (client == null)
                    client = new FXMindMQLClient(HostFromClient(tc), tc.port);
                Dictionary<string, string> paramsDic = new Dictionary<string, string>();
                FillParams(ref tc, parameters, paramsDic);
                List<string> list = StringToList(dataStr);
                resDblList = client.ProcessDoubleData(paramsDic, list);
                if (resDblList != null)
                {
                    resDblList.CopyTo(arr);
                }
            }
            catch (Exception)
            {
                client = null;
                return -1;
            }
            return 0;
        }

        [DllExport("ProcessStringData", CallingConvention = CallingConvention.StdCall)]
        public static long ProcessStringData([In, Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder str, [MarshalAs(UnmanagedType.LPWStr)]string parameters, ref THRIFT_CLIENT tc)
        {
            try
            {
                if (client == null)
                    client = new FXMindMQLClient(HostFromClient(tc), tc.port);
                List<string> list = StringToList(str.ToString());
                Dictionary<string, string> paramsDic = new Dictionary<string, string>();
                FillParams(ref tc, parameters, paramsDic);
                list = client.ProcessStringData(paramsDic, list);
                if (list.Count > 0)
                {
                    ListToString(ref str, list);
                    return list.Count;
                }
            }
            catch (Exception e)
            {
                string errstr = e.ToString();
                if (errstr.Length>100)
                errstr = errstr.Substring(0, 100);
                str.Append(errstr);
                client = null;
                return -1;
            }
            return 0;
        }

        [DllExport("IsServerActive", CallingConvention = CallingConvention.StdCall)]
        public static long IsServerActive(ref THRIFT_CLIENT tc)
        {
            try
            {
                if (client == null)
                    client = new FXMindMQLClient(HostFromClient(tc), tc.port);
                Dictionary<string, string> paramsDic = new Dictionary<string, string>();
                paramsDic["magic"] = tc.Magic.ToString();
                paramsDic["account"] = tc.accountNumber.ToString();
                return client.IsServerActive(paramsDic);
            }
            catch (Exception)
            {
                client = null;
                return -1;
            }
        }

        [DllExport("PostStatusMessage", CallingConvention = CallingConvention.StdCall)]
        public static void PostStatusMessage(ref THRIFT_CLIENT tc, [MarshalAs(UnmanagedType.LPWStr)]string message)
        {
            try
            {
                if (client == null)
                    client = new FXMindMQLClient(HostFromClient(tc), tc.port);
                Dictionary<string, string> paramsDic = new Dictionary<string, string>();
                paramsDic["magic"] = tc.Magic.ToString();
                paramsDic["account"] = tc.accountNumber.ToString();
                paramsDic["message"] = message;
                client.PostStatusMessage(paramsDic);
            }
            catch (Exception)
            {
                client = null;
            }
        }

        [DllExport("CloseClient", CallingConvention = CallingConvention.StdCall)]
        public static void CloseClient(ref THRIFT_CLIENT tc)
        {
            try
            {
                if (client != null)
                {
                    client.Dispose();
                    client = null;
                    GC.Collect();
                }
            }
            catch (Exception)
            {
                client = null;
            }
        }
    }
}
