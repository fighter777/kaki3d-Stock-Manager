<?php

namespace App\Repository;

use App\Infrastructure\DatabaseConnectionFactory;
use PDO;

class AuthRepository
{
    private DatabaseConnectionFactory $connectionFactory;

    public function __construct(DatabaseConnectionFactory $connectionFactory)
    {
        $this->connectionFactory = $connectionFactory;
    }

    public function initSchema(): void
    {
        $pdo = $this->connectionFactory->create();
        $pdo->exec(<<<SQL
            CREATE TABLE IF NOT EXISTS public.app_users (
                id_user SERIAL PRIMARY KEY,
                email TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            );
        SQL);

        $pdo->exec(<<<SQL
            CREATE TABLE IF NOT EXISTS public.api_tokens (
                id_token SERIAL PRIMARY KEY,
                id_user INT NOT NULL REFERENCES public.app_users(id_user) ON DELETE CASCADE,
                token_hash TEXT NOT NULL,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                revoked_at TIMESTAMPTZ NULL
            );
        SQL);

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
    }

    public function register(string $email, string $password): int
    {
        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare(
            'INSERT INTO public.app_users (email, password_hash) VALUES (:email, :password_hash) RETURNING id_user'
        );
        $stmt->execute([
            'email' => strtolower(trim($email)),
            'password_hash' => password_hash($password, PASSWORD_BCRYPT),
        ]);

        return (int) $stmt->fetchColumn();
    }

    public function authenticate(string $email, string $password): ?int
    {
        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare('SELECT id_user, password_hash FROM public.app_users WHERE email = :email LIMIT 1');
        $stmt->execute(['email' => strtolower(trim($email))]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user || !password_verify($password, $user['password_hash'])) {
            return null;
        }

        return (int) $user['id_user'];
    }

    public function issueToken(int $userId): string
    {
        $token = bin2hex(random_bytes(32));
        $tokenHash = hash('sha256', $token);

        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare(
            'INSERT INTO public.api_tokens (id_user, token_hash) VALUES (:id_user, :token_hash)'
        );
        $stmt->execute([
            'id_user' => $userId,
            'token_hash' => $tokenHash,
        ]);

        return $token;
    }

    public function isTokenValid(string $plainToken): bool
    {
        $tokenHash = hash('sha256', $plainToken);
        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare(
            'SELECT 1 FROM public.api_tokens
             WHERE token_hash = :token_hash
               AND revoked_at IS NULL
             LIMIT 1'
        );
        $stmt->execute(['token_hash' => $tokenHash]);

        return (bool) $stmt->fetchColumn();
    }

    public function revokeToken(string $plainToken): void
    {
        $tokenHash = hash('sha256', $plainToken);
        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare(
            'UPDATE public.api_tokens
             SET revoked_at = NOW()
             WHERE token_hash = :token_hash
               AND revoked_at IS NULL'
        );
        $stmt->execute(['token_hash' => $tokenHash]);
    }

    public function getUserIdByToken(string $plainToken): ?int
    {
        $tokenHash = hash('sha256', $plainToken);
        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare(
            'SELECT id_user
             FROM public.api_tokens
             WHERE token_hash = :token_hash
               AND revoked_at IS NULL
             LIMIT 1'
        );
        $stmt->execute(['token_hash' => $tokenHash]);
        $userId = $stmt->fetchColumn();

        return $userId !== false ? (int) $userId : null;
    }

    public function verifyUserPassword(int $userId, string $password): bool
    {
        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare('SELECT password_hash FROM public.app_users WHERE id_user = :id_user LIMIT 1');
        $stmt->execute(['id_user' => $userId]);
        $hash = $stmt->fetchColumn();

        return $hash !== false && password_verify($password, (string) $hash);
    }

    public function updatePassword(int $userId, string $newPassword): void
    {
        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare(
            'UPDATE public.app_users
             SET password_hash = :password_hash
             WHERE id_user = :id_user'
        );
        $stmt->execute([
            'password_hash' => password_hash($newPassword, PASSWORD_BCRYPT),
            'id_user' => $userId,
        ]);
    }

    public function revokeAllTokensForUser(int $userId): void
    {
        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare(
            'UPDATE public.api_tokens
             SET revoked_at = NOW()
             WHERE id_user = :id_user
               AND revoked_at IS NULL'
        );
        $stmt->execute(['id_user' => $userId]);
    }
}
