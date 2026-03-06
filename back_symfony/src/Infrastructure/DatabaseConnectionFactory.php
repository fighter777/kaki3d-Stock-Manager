<?php

namespace App\Infrastructure;

use PDO;
use RuntimeException;

class DatabaseConnectionFactory
{
    private string $host;
    private string $port;
    private string $dbName;
    private string $user;
    private string $password;
    private string $sslMode;

    public function __construct(
        string $host,
        string $port,
        string $dbName,
        string $user,
        string $password,
        string $sslMode,
    ) {
        $this->host = $host;
        $this->port = $port;
        $this->dbName = $dbName;
        $this->user = $user;
        $this->password = $password;
        $this->sslMode = $sslMode;
    }

    public function create(): PDO
    {
        $dsn = sprintf(
            'pgsql:host=%s;port=%s;dbname=%s;sslmode=%s',
            $this->host,
            $this->port,
            $this->dbName,
            $this->sslMode
        );

        $pdo = new PDO($dsn, $this->user, $this->password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);

        if (!$pdo) {
            throw new RuntimeException('Unable to connect to the database.');
        }

        return $pdo;
    }
}
