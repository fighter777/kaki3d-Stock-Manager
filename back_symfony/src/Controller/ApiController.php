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

    public function colors(SpoolRepository $spoolRepository): JsonResponse
    {
        return new JsonResponse($spoolRepository->getAllColors());
    }

    public function createBrand(Request $request, SpoolRepository $spoolRepository): JsonResponse
    {
        try {
            $payload = $this->parseJson($request);
        } catch (\InvalidArgumentException $e) {
            return new JsonResponse(['message' => $e->getMessage()], 400);
        }

        $name = trim((string) ($payload['name'] ?? ''));
        if ($name === '') {
            return new JsonResponse(['message' => 'Missing or invalid field: name'], 400);
        }

        try {
            $created = $spoolRepository->createBrand($name);
        } catch (\Throwable $e) {
            return new JsonResponse(['message' => 'Create brand failed', 'detail' => $e->getMessage()], 400);
        }

        return new JsonResponse($created, 201);
    }

    public function createMaterial(Request $request, SpoolRepository $spoolRepository): JsonResponse
    {
        try {
            $payload = $this->parseJson($request);
        } catch (\InvalidArgumentException $e) {
            return new JsonResponse(['message' => $e->getMessage()], 400);
        }

        $name = trim((string) ($payload['name'] ?? ''));
        if ($name === '') {
            return new JsonResponse(['message' => 'Missing or invalid field: name'], 400);
        }

        try {
            $created = $spoolRepository->createMaterial($name);
        } catch (\Throwable $e) {
            return new JsonResponse(['message' => 'Create material failed', 'detail' => $e->getMessage()], 400);
        }

        return new JsonResponse($created, 201);
    }

    public function createColor(Request $request, SpoolRepository $spoolRepository): JsonResponse
    {
        try {
            $payload = $this->parseJson($request);
        } catch (\InvalidArgumentException $e) {
            return new JsonResponse(['message' => $e->getMessage()], 400);
        }

        $name = trim((string) ($payload['name'] ?? ''));
        if ($name === '') {
            return new JsonResponse(['message' => 'Missing or invalid field: name'], 400);
        }

        try {
            $created = $spoolRepository->createColor($name);
        } catch (\Throwable $e) {
            return new JsonResponse(['message' => 'Create color failed', 'detail' => $e->getMessage()], 400);
        }

        return new JsonResponse($created, 201);
    }

    public function deleteBrand(int $id, SpoolRepository $spoolRepository): JsonResponse
    {
        try {
            $deleted = $spoolRepository->deleteBrand($id);
        } catch (\RuntimeException $e) {
            return new JsonResponse(['message' => 'Brand is used by existing spools'], 409);
        } catch (\Throwable $e) {
            return new JsonResponse(['message' => 'Delete brand failed', 'detail' => $e->getMessage()], 400);
        }

        if (!$deleted) {
            return new JsonResponse(['message' => 'Brand not found'], 404);
        }

        return new JsonResponse(['status' => 'deleted']);
    }

    public function deleteMaterial(int $id, SpoolRepository $spoolRepository): JsonResponse
    {
        try {
            $deleted = $spoolRepository->deleteMaterial($id);
        } catch (\RuntimeException $e) {
            return new JsonResponse(['message' => 'Material is used by existing spools'], 409);
        } catch (\Throwable $e) {
            return new JsonResponse(['message' => 'Delete material failed', 'detail' => $e->getMessage()], 400);
        }

        if (!$deleted) {
            return new JsonResponse(['message' => 'Material not found'], 404);
        }

        return new JsonResponse(['status' => 'deleted']);
    }

    public function deleteColor(int $id, SpoolRepository $spoolRepository): JsonResponse
    {
        try {
            $deleted = $spoolRepository->deleteColor($id);
        } catch (\RuntimeException $e) {
            return new JsonResponse(['message' => 'Color is used by existing spools'], 409);
        } catch (\Throwable $e) {
            return new JsonResponse(['message' => 'Delete color failed', 'detail' => $e->getMessage()], 400);
        }

        if (!$deleted) {
            return new JsonResponse(['message' => 'Color not found'], 404);
        }

        return new JsonResponse(['status' => 'deleted']);
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

        if (!array_key_exists('initial_weight', $payload)) {
            return new JsonResponse(['message' => 'Missing field: initial_weight'], 400);
        }
        if (!array_key_exists('brand_id', $payload) && !array_key_exists('brand_name', $payload)) {
            return new JsonResponse(['message' => 'Missing field: brand_id'], 400);
        }
        if (!array_key_exists('material_id', $payload) && !array_key_exists('material_name', $payload)) {
            return new JsonResponse(['message' => 'Missing field: material_id'], 400);
        }
        if (!array_key_exists('color_id', $payload) && !array_key_exists('color_name', $payload)) {
            return new JsonResponse(['message' => 'Missing field: color_id'], 400);
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
