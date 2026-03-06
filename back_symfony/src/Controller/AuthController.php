<?php

namespace App\Controller;

use App\Repository\AuthRepository;
use App\Security\AuditLogger;
use App\Security\AuthRateLimiter;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class AuthController
{
    private AuthRateLimiter $rateLimiter;
    private AuditLogger $auditLogger;

    public function __construct(AuthRateLimiter $rateLimiter, AuditLogger $auditLogger)
    {
        $this->rateLimiter = $rateLimiter;
        $this->auditLogger = $auditLogger;
    }

    private function extractBearerToken(Request $request): ?string
    {
        $authorization = trim((string) $request->headers->get('Authorization', ''));
        if (!str_starts_with($authorization, 'Bearer ')) {
            return null;
        }

        $token = trim(substr($authorization, 7));
        return $token !== '' ? $token : null;
    }

    public function register(Request $request, AuthRepository $authRepository): JsonResponse
    {
        $authRepository->initSchema();
        $ip = (string) ($request->getClientIp() ?? 'unknown');
        $registerLimit = $this->rateLimiter->consume('register_ip', $ip, 5, 60);
        if (!$registerLimit['allowed']) {
            $this->auditLogger->log(
                'register',
                false,
                'Rate limit exceeded',
                $ip,
                null,
                null,
                ['retry_after_seconds' => $registerLimit['retry_after_seconds']]
            );
            return new JsonResponse([
                'message' => 'Trop de tentatives de creation de compte',
                'retry_after_seconds' => $registerLimit['retry_after_seconds'],
            ], 429);
        }

        try {
            $payload = $request->toArray();
        } catch (\Throwable) {
            $this->auditLogger->log('register', false, 'Invalid JSON payload', $ip);
            return new JsonResponse(['message' => 'Invalid JSON payload'], 400);
        }

        $email = strtolower(trim((string) ($payload['email'] ?? '')));
        $password = (string) ($payload['password'] ?? '');

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->auditLogger->log('register', false, 'Invalid email', $ip, $email);
            return new JsonResponse(['message' => 'Email invalide'], 400);
        }
        if (strlen($password) < 8) {
            $this->auditLogger->log('register', false, 'Password too short', $ip, $email);
            return new JsonResponse(['message' => 'Mot de passe trop court (8 caracteres minimum)'], 400);
        }

        try {
            $userId = $authRepository->register($email, $password);
            $token = $authRepository->issueToken($userId);
        } catch (\Throwable $e) {
            $this->auditLogger->log('register', false, 'Create account failed', $ip, $email, null, ['detail' => $e->getMessage()]);
            return new JsonResponse(['message' => 'Echec creation compte', 'detail' => $e->getMessage()], 409);
        }

        $this->auditLogger->log('register', true, 'Account created', $ip, $email, $userId);

        return new JsonResponse([
            'status' => 'created',
            'user_id' => $userId,
            'access_token' => $token,
            'token_type' => 'Bearer',
        ], 201);
    }

    public function login(Request $request, AuthRepository $authRepository): JsonResponse
    {
        $authRepository->initSchema();
        $ip = (string) ($request->getClientIp() ?? 'unknown');
        $ipLimit = $this->rateLimiter->consume('login_ip', $ip, 10, 60);
        if (!$ipLimit['allowed']) {
            $this->auditLogger->log(
                'login',
                false,
                'Rate limit exceeded (ip)',
                $ip,
                null,
                null,
                ['retry_after_seconds' => $ipLimit['retry_after_seconds']]
            );
            return new JsonResponse([
                'message' => 'Trop de tentatives de connexion',
                'retry_after_seconds' => $ipLimit['retry_after_seconds'],
            ], 429);
        }

        try {
            $payload = $request->toArray();
        } catch (\Throwable) {
            $this->auditLogger->log('login', false, 'Invalid JSON payload', $ip);
            return new JsonResponse(['message' => 'Invalid JSON payload'], 400);
        }

        $email = strtolower(trim((string) ($payload['email'] ?? '')));
        $password = (string) ($payload['password'] ?? '');
        $emailLimit = $this->rateLimiter->consume('login_email', $email, 7, 60);
        if (!$emailLimit['allowed']) {
            $this->auditLogger->log(
                'login',
                false,
                'Rate limit exceeded (email)',
                $ip,
                $email,
                null,
                ['retry_after_seconds' => $emailLimit['retry_after_seconds']]
            );
            return new JsonResponse([
                'message' => 'Trop de tentatives pour ce compte',
                'retry_after_seconds' => $emailLimit['retry_after_seconds'],
            ], 429);
        }

        $userId = $authRepository->authenticate($email, $password);
        if ($userId === null) {
            $this->auditLogger->log('login', false, 'Invalid credentials', $ip, $email);
            return new JsonResponse(['message' => 'Identifiants invalides'], 401);
        }

        $token = $authRepository->issueToken($userId);
        $this->auditLogger->log('login', true, 'Login success', $ip, $email, $userId);

        return new JsonResponse([
            'status' => 'ok',
            'user_id' => $userId,
            'access_token' => $token,
            'token_type' => 'Bearer',
        ]);
    }

    public function logout(Request $request, AuthRepository $authRepository): JsonResponse
    {
        $authRepository->initSchema();
        $ip = (string) ($request->getClientIp() ?? 'unknown');
        $token = $this->extractBearerToken($request);
        if ($token === null) {
            $this->auditLogger->log('logout', false, 'Missing bearer token', $ip);
            return new JsonResponse(['message' => 'Authorization Bearer token requis'], 401);
        }

        $userId = $authRepository->getUserIdByToken($token);
        $authRepository->revokeToken($token);
        $this->auditLogger->log('logout', true, 'Logout success', $ip, null, $userId);

        return new JsonResponse(['status' => 'logged_out']);
    }

    public function changePassword(Request $request, AuthRepository $authRepository): JsonResponse
    {
        $authRepository->initSchema();
        $ip = (string) ($request->getClientIp() ?? 'unknown');
        $token = $this->extractBearerToken($request);
        if ($token === null) {
            $this->auditLogger->log('change_password', false, 'Missing bearer token', $ip);
            return new JsonResponse(['message' => 'Authorization Bearer token requis'], 401);
        }

        $userId = $authRepository->getUserIdByToken($token);
        if ($userId === null) {
            $this->auditLogger->log('change_password', false, 'Invalid token', $ip);
            return new JsonResponse(['message' => 'Token invalide'], 401);
        }

        try {
            $payload = $request->toArray();
        } catch (\Throwable) {
            $this->auditLogger->log('change_password', false, 'Invalid JSON payload', $ip, null, $userId);
            return new JsonResponse(['message' => 'Invalid JSON payload'], 400);
        }

        $currentPassword = (string) ($payload['current_password'] ?? '');
        $newPassword = (string) ($payload['new_password'] ?? '');

        if (strlen($newPassword) < 8) {
            $this->auditLogger->log('change_password', false, 'New password too short', $ip, null, $userId);
            return new JsonResponse(['message' => 'Nouveau mot de passe trop court (8 caracteres minimum)'], 400);
        }

        if (!$authRepository->verifyUserPassword($userId, $currentPassword)) {
            $this->auditLogger->log('change_password', false, 'Invalid current password', $ip, null, $userId);
            return new JsonResponse(['message' => 'Mot de passe actuel invalide'], 401);
        }

        $authRepository->updatePassword($userId, $newPassword);
        $authRepository->revokeAllTokensForUser($userId);
        $newToken = $authRepository->issueToken($userId);
        $this->auditLogger->log('change_password', true, 'Password changed', $ip, null, $userId);

        return new JsonResponse([
            'status' => 'password_changed',
            'access_token' => $newToken,
            'token_type' => 'Bearer',
        ]);
    }
}
