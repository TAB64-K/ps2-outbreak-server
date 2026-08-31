<?php
    $serv = 'bioserver2';
    $datb = 'bioserver2';
    $user = 'bioserver';
    $pass = 'changeme';
    
    $conn = mysql_connect($serv, $user, $pass)
        or die ("connection error");

    mysql_select_db($datb, $conn)
        or die("database failure");
?>