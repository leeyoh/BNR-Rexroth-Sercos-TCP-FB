
PROGRAM _INIT
	(* Insert code here *)
	SIP_0.IpAddress := '192.168.1.25';
	SIP_0.Port := 10000;
	
	SIP_1.IpAddress := '192.168.1.26';
	SIP_1.Port := 10000;
END_PROGRAM

PROGRAM _CYCLIC
	(* Insert code here *)
	SIP_0;
	SIP_1;
END_PROGRAM

PROGRAM _EXIT
	(* Insert code here *)
	 
END_PROGRAM

