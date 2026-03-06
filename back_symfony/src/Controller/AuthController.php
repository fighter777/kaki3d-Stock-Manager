<?php

namespace App\Controller;

use App\Repository\AuthRepository;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class AuthController
{
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

        try {
            $payload = $request->toArray();
        } catch (\Throwable) {
            return new JsonResponse(['message' => 'Invalid JSON payload'], 400);
        }

        $email = strtolower(trim((string) ($payload['email'] ?? '')));
        $password = (string) ($payload['password'] ?? '');

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
