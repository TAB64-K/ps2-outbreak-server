<?php
    $serv = "bioserver1";
    $datb = "bioserver";
    $user = "bioserver";
    $pass = "changeme";
    $conn = mysqli_connect($serv, $user, $pass, $datb)
        or die("connection error");