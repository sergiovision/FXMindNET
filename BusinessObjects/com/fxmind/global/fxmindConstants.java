/**
 * Autogenerated by Thrift Compiler (0.9.1)
 *
 * DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
 *  @generated
 */
package com.fxmind.global;

import org.apache.thrift.scheme.IScheme;
import org.apache.thrift.scheme.SchemeFactory;
import org.apache.thrift.scheme.StandardScheme;

import org.apache.thrift.scheme.TupleScheme;
import org.apache.thrift.protocol.TTupleProtocol;
import org.apache.thrift.protocol.TProtocolException;
import org.apache.thrift.EncodingUtils;
import org.apache.thrift.TException;
import org.apache.thrift.async.AsyncMethodCallback;
import org.apache.thrift.server.AbstractNonblockingServer.*;
import java.util.List;
import java.util.ArrayList;
import java.util.Map;
import java.util.HashMap;
import java.util.EnumMap;
import java.util.Set;
import java.util.HashSet;
import java.util.EnumSet;
import java.util.Collections;
import java.util.BitSet;
import java.nio.ByteBuffer;
import java.util.Arrays;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class fxmindConstants {

  /**
   * Thrift also lets you define constants for use across languages. Complex
   * types and structs are specified using JSON notation.
   */
  public static final double GAP_VALUE = -125;

  public static final String MTDATETIMEFORMAT = "yyyy.MM.dd HH:mm";

  public static final String MYSQLDATETIMEFORMAT = "yyyy-MM-dd HH:mm:ss";

  public static final int SENTIMENTS_FETCH_PERIOD = 100;

  public static final short FXMindMQL_PORT = (short)2011;

  public static final short AppService_PORT = (short)2012;

  public static final String JOBGROUP_TECHDETAIL = "Technical Details";

  public static final String JOBGROUP_OPENPOSRATIO = "Positions Ratio";

  public static final String JOBGROUP_EXECRULES = "Run Rules";

  public static final String JOBGROUP_NEWS = "News";

  public static final String JOBGROUP_THRIFT = "ThriftServer";

  public static final String CRON_MANUAL = "0 0 0 1 1 ? 2100";

}