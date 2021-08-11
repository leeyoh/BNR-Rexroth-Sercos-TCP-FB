
TYPE
	Data_typ : 	STRUCT 
		Receive : ARRAY[0..999]OF UDINT;
		Send : ARRAY[0..999]OF UDINT;
		NumBytes : UDINT;
		BitMask : UDINT;
		ControlWord : UDINT;
	END_STRUCT;
	Client_typ : 	STRUCT  (*TCP Client Variables*)
		sStep : UINT; (*TCP Client Step Variable*)
		TcpOpen_0 : TcpOpen; (*AsTCP.TcpOpen FUB*)
		TcpClient_0 : TcpClient; (*AsTCP.TcpClient FUB*)
		TcpRecv_0 : TcpRecv; (*AsTCP.TcpRecv FUB*)
		TcpSend_0 : TcpSend; (*AsTCP.TcpSend FUB*)
		TcpIoctl_0 : TcpIoctl; (*AsTCP.TcpIoctl FUB*)
		TcpClose_0 : TcpClose; (*AsTCP.TcpClose FUB*)
		linger_opt : tcpLINGER_typ; (*AsTCP.tcpLINGER_typ*)
		recv_timeout : UDINT; (*receive timeout*)
	END_STRUCT;
	Internal_typ : 	STRUCT 
		MsgNum : UDINT;
		ConnectSip : BOOL;
		_SipConnected : BOOL;
		_Velocity : REAL;
		TON_Read : TON;
		AttemptCounter : USINT;
		Counter : USINT;
		StatusUpdate : BOOL;
	END_STRUCT;
END_TYPE
