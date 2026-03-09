<?php

namespace App\Controller;

use App\Repository\SpoolRepository;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;

class ApiController
{
    private function parseJson(Request $request): array
    {
        try {
            return $request->toArray();
        } catch (\Throwable) {
            throw new \InvalidArgumentException('Invalid JSON payload');
        }
    }

    public function health(): JsonResponse
    {
        return new JsonResponse(['status' => 'ok']);
    }

    public function inventory(SpoolRepository $spoolRepository): JsonResponse
    {
        return new JsonResponse($spoolRepository->getInventory());
    }

    public function inventoryAggregated(SpoolRepository $spoolRepository): JsonResponse
    {
        return new JsonResponse($spoolRepository->getAggregatedInventory());
    }

    public function brands(SpoolRepository $spoolRepository): JsonResponse
    {
        return new JsonResponse($spoolRepository->getAllBrands());
    }

    public function materials(SpoolRepository $spoolRepository): JsonResponse
    {
        return new JsonResponse($spoolRepository->getAllMaterials());
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
            $payload = $this->parseJson($request);
        } catch (\InvalidArgumentException $e) {
            return new JsonResponse(['message' => $e->getMessage()], 400);
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

    public function createSpool(Request $request, SpoolRepository $spoolRepository): JsonResponse
    {
        try {
            $payload = $this->parseJson($request);
        } catch (\InvalidArgumentException $e) {
            return new JsonResponse(['message' => $e->getMessage()], 400);
        }

        foreach (['brand_name', 'material_name', 'color_name', 'initial_weight'] as $field) {
            if (!array_key_exists($field, $payload)) {
                return new JsonResponse(['message' => sprintf('Missing field: %s', $field)], 400);
            }
        }

        try {
            $spool = $spoolRepository->createSpool($payload);
        } catch (\Throwable $e) {
            return new JsonResponse(['message' => 'Create spool failed', 'detail' => $e->getMessage()], 400);
        }

        return new JsonResponse($spool, 201);
    }

    public function updateSpool(int $id, Request $request, SpoolRepository $spoolRepository): JsonResponse
    {
        try {
            $payload = $this->parseJson($request);
        } catch (\InvalidArgumentException $e) {
            return new JsonResponse(['message' => $e->getMessage()], 400);
        }

        try {
            $spool = $spoolRepository->updateSpool($id, $payload);
        } catch (\Throwable $e) {
            return new JsonResponse(['message' => 'Update spool failed', 'detail' => $e->getMessage()], 400);
        }

        if ($spool === null) {
            return new JsonResponse(['message' => 'Spool not found'], 404);
        }

        return new JsonResponse($spool);
    }

    public function deleteSpool(int $id, SpoolRepository $spoolRepository): JsonResponse
    {
        $deleted = $spoolRepository->deleteSpool($id);
        if (!$deleted) {
            return new JsonResponse(['message' => 'Spool not found'], 404);
        }

        return new JsonResponse(['status' => 'deleted']);
    }

    public function cloneSpool(int $id, Request $request, SpoolRepository $spoolRepository): JsonResponse
    {
        $payload = [];
        if ($request->getContent() !== '') {
            try {
                $payload = $this->parseJson($request);
            } catch (\InvalidArgumentException $e) {
                return new JsonResponse(['message' => $e->getMessage()], 400);
            }
        }

        $nfcId = array_key_exists('nfc_id', $payload) ? trim((string) $payload['nfc_id']) : null;

        try {
            $cloned = $spoolRepository->cloneSpool($id, $nfcId !== '' ? $nfcId : null);
        } catch (\Throwable $e) {
            return new JsonResponse(['message' => 'Clone spool failed', 'detail' => $e->getMessage()], 400);
        }

        if ($cloned === null) {
            return new JsonResponse(['message' => 'Spool not found'], 404);
        }

        return new JsonResponse($cloned, 201);
    }

    public function statsByMaterial(SpoolRepository $spoolRepository): JsonResponse
    {
        return new JsonResponse($spoolRepository->getStatsByMaterial());
    }

    public function statsByProject(SpoolRepository $spoolRepository): JsonResponse
    {
        return new JsonResponse($spoolRepository->getStatsByProject());
    }

    public function statsByMonth(SpoolRepository $spoolRepository): JsonResponse
    {
        return new JsonResponse($spoolRepository->getStatsByMonth());
    }
}
