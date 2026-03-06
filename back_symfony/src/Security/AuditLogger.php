<?php

namespace App\Security;

use App\Infrastructure\DatabaseConnectionFactory;
use PDO;

class AuditLogger
{
    private DatabaseConnectionFactory $connectionFactory;
    private bool $schemaInitialized = false;

    public function __construct(DatabaseConnectionFactory $connectionFactory)
    {
        $this->connectionFactory = $connectionFactory;
    }

    public function log(
        string $eventType,
        bool $success,
        ?string $message = null,
        ?string $ipAddress = null,
        ?string $email = null,
        ?int $userId = null,
        array $metadata = []
    ): void {
        try {
            $this->ensureSchema();
            $pdo = $this->connectionFactory->create();
            $stmt = $pdo->prepare(
                'INSERT INTO public.app_audit_logs (
                    event_type, success, message, ip_address, email, user_id, metadata
                 ) VALUES (
                    :event_type, :success, :message, :ip_address, :email, :user_id, :metadata
                 )'
            );
            $stmt->bindValue('event_type', $eventType, PDO::PARAM_STR);
            $stmt->bindValue('success', $success, PDO::PARAM_BOOL);
            $stmt->bindValue('message', $message, PDO::PARAM_STR);
            $stmt->bindValue('ip_address', $ipAddress, PDO::PARAM_STR);
            $stmt->bindValue('email', $email, PDO::PARAM_STR);
            $stmt->bindValue('user_id', $userId, $userId === null ? PDO::PARAM_NULL : PDO::PARAM_INT);
            $stmt->bindValue('metadata', empty($metadata) ? null : json_encode($metadata), empty($metadata) ? PDO::PARAM_NULL : PDO::PARAM_STR);
            $stmt->execute();
        } catch (\Throwable) {
            // We never want auditing failures to break the functional flow.
        }
    }

    private function ensureSchema(): void
    {
        if ($this->schemaInitialized) {
            return;
        }

        $pdo = $this->connectionFactory->create();
        $pdo->exec(<<<SQL
            CREATE TABLE IF NOT EXISTS public.app_audit_logs (
                id_audit SERIAL PRIMARY KEY,
                event_type TEXT NOT NULL,
                success BOOLEAN NOT NULL,
                message TEXT NULL,
                ip_address TEXT NULL,
                email TEXT NULL,
                user_id INT NULL,
                metadata JSONB NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
        SQL);
        $this->schemaInitialized = true;
    }
}

