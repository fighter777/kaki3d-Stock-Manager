<?php

namespace App\Repository;

use App\Infrastructure\DatabaseConnectionFactory;
use DateTimeImmutable;
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
                expires_at TIMESTAMPTZ NOT NULL,
                revoked_at TIMESTAMPTZ NULL
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

    public function issueToken(int $userId, int $ttlHours = 24): string
    {
        $token = bin2hex(random_bytes(32));
        $tokenHash = hash('sha256', $token);
        $expiresAt = (new DateTimeImmutable(sprintf('+%d hours', $ttlHours)))->format('Y-m-d H:i:sP');

        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare(
            'INSERT INTO public.api_tokens (id_user, token_hash, expires_at) VALUES (:id_user, :token_hash, :expires_at)'
        );
        $stmt->execute([
            'id_user' => $userId,
            'token_hash' => $tokenHash,
            'expires_at' => $expiresAt,
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
               AND expires_at > NOW()
             LIMIT 1'
        );
        $stmt->execute(['token_hash' => $tokenHash]);

        return (bool) $stmt->fetchColumn();
    }
}

