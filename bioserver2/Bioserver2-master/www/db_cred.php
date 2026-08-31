<?php
    $serv = "bioserver2";
    $datb = "bioserver2";
    $user = "bioserver";
    $pass = "changeme";

    $conn = mysqli_connect($serv, $user, $pass, $datb)
        or die("connection error");
?>