<?php

namespace App\Controller;

use App\Repository\SpoolRepository;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class ApiController
{
    public function health(): JsonResponse
    {
        return new JsonResponse(['status' => 'ok']);
    }

    public function inventory(SpoolRepository $spoolRepository): JsonResponse
    {
        return new JsonResponse($spoolRepository->getInventory());
    }

    public function spoolByNfc(string $uid, SpoolRepository $spoolRepository): JsonResponse
    {
        $spool = $spoolRepository->getByNfcUid($uid);
        if ($spool === null) {
            return new JsonResponse(['message' => 'Spool not found'], 404);
        }

        return new JsonResponse($spool);
    }

    public function createUsage(Request $request, SpoolRepository $spoolRepository): JsonResponse
    {
        try {
            $payload = $request->toArray();
        } catch (\Throwable) {
            return new JsonResponse(['message' => 'Invalid JSON payload'], 400);
        }

        $requiredFields = ['weight_used', 'print_date', 'id_spools', 'project_name'];
        foreach ($requiredFields as $field) {
            if (!array_key_exists($field, $payload)) {
                return new JsonResponse(['message' => sprintf('Missing field: %s', $field)], 400);
            }
        }

        $weightUsed = (float) $payload['weight_used'];
        $spoolId = (int) $payload['id_spools'];
        $projectName = trim((string) $payload['project_name']);
        $printDate = (string) $payload['print_date'];

        if ($weightUsed <= 0 || $spoolId <= 0 || $projectName === '') {
            return new JsonResponse(['message' => 'Invalid payload values'], 400);
        }

        $spoolRepository->addUsageLog($weightUsed, $printDate, $spoolId, $projectName);

        return new JsonResponse(['status' => 'created'], 201);
    }
}

