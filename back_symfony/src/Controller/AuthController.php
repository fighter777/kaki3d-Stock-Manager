<?php

namespace App\Controller;

use App\Repository\AuthRepository;
use App\Security\AuthRateLimiter;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class AuthController
{
    private AuthRateLimiter $rateLimiter;

    public function __construct(AuthRateLimiter $rateLimiter)
    {
        $this->rateLimiter = $rateLimiter;
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
            return new JsonResponse([
                'message' => 'Trop de tentatives de creation de compte',
                'retry_after_seconds' => $registerLimit['retry_after_seconds'],
            ], 429);
        }

        try {
            $payload = $request->toArray();
        } catch (\Throwable) {
            return new JsonResponse(['message' => 'Invalid JSON payload'], 400);
        }

        $email = strtolower(trim((string) ($payload['email'] ?? '')));
        $password = (string) ($payload['password'] ?? '');

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            return new JsonResponse(['message' => 'Email invalide'], 400);
        }
        if (strlen($password) < 8) {
            return new JsonResponse(['message' => 'Mot de passe trop court (8 caracteres minimum)'], 400);
        }

        try {
            $userId = $authRepository->register($email, $password);
            $token = $authRepository->issueToken($userId);
        } catch (\Throwable $e) {
            return new JsonResponse(['message' => 'Echec creation compte', 'detail' => $e->getMessage()], 409);
        }

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
            return new JsonResponse([
                'message' => 'Trop de tentatives de connexion',
                'retry_after_seconds' => $ipLimit['retry_after_seconds'],
            ], 429);
        }

        try {
            $payload = $request->toArray();
        } catch (\Throwable) {
            return new JsonResponse(['message' => 'Invalid JSON payload'], 400);
        }

        $email = strtolower(trim((string) ($payload['email'] ?? '')));
        $password = (string) ($payload['password'] ?? '');
        $emailLimit = $this->rateLimiter->consume('login_email', $email, 7, 60);
        if (!$emailLimit['allowed']) {
            return new JsonResponse([
                'message' => 'Trop de tentatives pour ce compte',
                'retry_after_seconds' => $emailLimit['retry_after_seconds'],
            ], 429);
        }

        $userId = $authRepository->authenticate($email, $password);
        if ($userId === null) {
            return new JsonResponse(['message' => 'Identifiants invalides'], 401);
        }

        $token = $authRepository->issueToken($userId);

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
        $token = $this->extractBearerToken($request);
        if ($token === null) {
            return new JsonResponse(['message' => 'Authorization Bearer token requis'], 401);
        }

        $authRepository->revokeToken($token);

        return new JsonResponse(['status' => 'logged_out']);
    }

    public function changePassword(Request $request, AuthRepository $authRepository): JsonResponse
    {
        $authRepository->initSchema();
        $token = $this->extractBearerToken($request);
        if ($token === null) {
            return new JsonResponse(['message' => 'Authorization Bearer token requis'], 401);
        }

        $userId = $authRepository->getUserIdByToken($token);
        if ($userId === null) {
            return new JsonResponse(['message' => 'Token invalide'], 401);
        }

        try {
            $payload = $request->toArray();
        } catch (\Throwable) {
            return new JsonResponse(['message' => 'Invalid JSON payload'], 400);
        }

        $currentPassword = (string) ($payload['current_password'] ?? '');
        $newPassword = (string) ($payload['new_password'] ?? '');

        if (strlen($newPassword) < 8) {
            return new JsonResponse(['message' => 'Nouveau mot de passe trop court (8 caracteres minimum)'], 400);
        }

        if (!$authRepository->verifyUserPassword($userId, $currentPassword)) {
            return new JsonResponse(['message' => 'Mot de passe actuel invalide'], 401);
        }

        $authRepository->updatePassword($userId, $newPassword);
        $authRepository->revokeAllTokensForUser($userId);
        $newToken = $authRepository->issueToken($userId);

        return new JsonResponse([
            'status' => 'password_changed',
            'access_token' => $newToken,
            'token_type' => 'Bearer',
        ]);
    }
}
