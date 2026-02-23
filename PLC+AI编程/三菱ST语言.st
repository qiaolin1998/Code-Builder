
;IF M8002 THEN    	 
    M0 := TRUE;
    M1 := FALSE;
    M2 := FALSE;
    M3 := FALSE;
END_IF;




;IF M0 AND X0  THEN	
    M1 := TRUE;
    M0 := FALSE;  
END_IF;



;IF M1  THEN
	  Y0 := TRUE;   
END_IF;

OUT_T( M1, TC0 , 20 );

;IF M1  AND   TS0 THEN
	  M2 := TRUE;
      M1 := FALSE;   
    
END_IF;



;IF M2  THEN
	  Y1 := TRUE;  
END_IF;



;IF M2  AND   X2 THEN
	  M3 := TRUE;
      M2 := FALSE;     
END_IF;



;IF M3  THEN
	  Y0 := FALSE;
	  Y1 := FALSE;   
END_IF;



;IF M3  AND X3 THEN
	  M0 := TRUE;
      M3 := FALSE;   
END_IF;

