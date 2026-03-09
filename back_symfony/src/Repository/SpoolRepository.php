<?php

namespace App\Repository;

use App\Infrastructure\DatabaseConnectionFactory;
use PDO;

class SpoolRepository
{
    private DatabaseConnectionFactory $connectionFactory;

    public function __construct(DatabaseConnectionFactory $connectionFactory)
    {
        $this->connectionFactory = $connectionFactory;
    }

    public function getInventory(): array
    {
        $sql = <<<SQL
            SELECT
                s.*,
                m.nom_marques,
                mat.type_materials,
                (s.initial_weight - COALESCE(SUM(u.weight_used), 0)) AS poids_restant
            FROM public.spools s
            JOIN public.marques m ON s.id_marques = m.id_marques
            JOIN public.materials mat ON s.id_materials = mat.id_materials
            LEFT JOIN public.usage_logs u ON s.id_spools = u.id_spools
            GROUP BY s.id_spools, m.id_marques, m.nom_marques, mat.id_materials, mat.type_materials
            ORDER BY s.id_spools DESC
        SQL;

        return $this->runQuery($sql);
    }

    public function getAggregatedInventory(): array
    {
        $sql = <<<SQL
            SELECT
                m.nom_marques,
                mat.type_materials,
                s.color_name,
                SUM(s.initial_weight) AS total_initial,
                (SUM(s.initial_weight) - COALESCE(SUM(u.weight_used), 0)) AS total_restant
            FROM public.spools s
            JOIN public.marques m ON s.id_marques = m.id_marques
            JOIN public.materials mat ON s.id_materials = mat.id_materials
            LEFT JOIN public.usage_logs u ON s.id_spools = u.id_spools
            GROUP BY m.nom_marques, mat.type_materials, s.color_name
            ORDER BY m.nom_marques
        SQL;

        return $this->runQuery($sql);
    }

    public function getAllBrands(): array
    {
        $sql = 'SELECT id_marques, nom_marques FROM public.marques ORDER BY nom_marques';

        return $this->runQuery($sql);
    }

    public function getAllMaterials(): array
    {
        $sql = 'SELECT id_materials, type_materials FROM public.materials ORDER BY type_materials';

        return $this->runQuery($sql);
    }

    public function getByNfcUid(string $uid): ?array
    {
        $sql = <<<SQL
            SELECT
                s.*,
                m.nom_marques,
                mat.type_materials,
                (s.initial_weight - COALESCE(SUM(u.weight_used), 0)) AS poids_restant
            FROM public.spools s
            JOIN public.marques m ON s.id_marques = m.id_marques
            JOIN public.materials mat ON s.id_materials = mat.id_materials
            LEFT JOIN public.usage_logs u ON s.id_spools = u.id_spools
            WHERE s.nfc_id ILIKE :uid
            GROUP BY s.id_spools, m.id_marques, m.nom_marques, mat.id_materials, mat.type_materials
            LIMIT 1
        SQL;

        $result = $this->runQuery($sql, ['uid' => trim($uid)]);

        return $result[0] ?? null;
    }

    public function addUsageLog(float $weightUsed, string $printDate, int $spoolId, string $projectName): void
    {
        $sql = <<<SQL
            INSERT INTO public.usage_logs (weight_used, print_date, id_spools, project_name)
            VALUES (:weight_used, :print_date, :id_spools, :project_name)
        SQL;

        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            'weight_used' => $weightUsed,
            'print_date' => $printDate,
            'id_spools' => $spoolId,
            'project_name' => $projectName,
        ]);
    }

    public function createSpool(array $payload): array
    {
        $pdo = $this->connectionFactory->create();
        $pdo->beginTransaction();

        try {
            $brandId = $this->getOrCreateId($pdo, 'marques', 'nom_marques', 'id_marques', (string) $payload['brand_name']);
            $materialId = $this->getOrCreateId($pdo, 'materials', 'type_materials', 'id_materials', (string) $payload['material_name']);

            $stmt = $pdo->prepare(
                'INSERT INTO public.spools (
                    nfc_id, color_name, initial_weight, empty_spool_weight,
                    diametre, temperature_imp, temperature_table, debit,
                    pressure_advance, vit_volum_max, vit_imp, id_marques, id_materials
                ) VALUES (
                    :nfc_id, :color_name, :initial_weight, :empty_spool_weight,
                    :diametre, :temperature_imp, :temperature_table, :debit,
                    :pressure_advance, :vit_volum_max, :vit_imp, :id_marques, :id_materials
                ) RETURNING id_spools'
            );

            $stmt->execute([
                'nfc_id' => (string) ($payload['nfc_id'] ?? ''),
                'color_name' => (string) $payload['color_name'],
                'initial_weight' => (float) $payload['initial_weight'],
                'empty_spool_weight' => (float) ($payload['empty_spool_weight'] ?? 200),
                'diametre' => (float) ($payload['diametre'] ?? 1.75),
                'temperature_imp' => (float) ($payload['temperature_imp'] ?? 200),
                'temperature_table' => (float) ($payload['temperature_table'] ?? 50),
                'debit' => (float) ($payload['debit'] ?? 100),
                'pressure_advance' => (float) ($payload['pressure_advance'] ?? 0),
                'vit_volum_max' => (float) ($payload['vit_volum_max'] ?? 15),
                'vit_imp' => (float) ($payload['vit_imp'] ?? 60),
                'id_marques' => $brandId,
                'id_materials' => $materialId,
            ]);

            $spoolId = (int) $stmt->fetchColumn();
            $pdo->commit();

            return $this->getById($spoolId) ?? [];
        } catch (\Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    public function updateSpool(int $spoolId, array $payload): ?array
    {
        $existing = $this->getById($spoolId);
        if ($existing === null) {
            return null;
        }

        $pdo = $this->connectionFactory->create();
        $pdo->beginTransaction();

        try {
            $brandName = (string) ($payload['brand_name'] ?? $existing['nom_marques']);
            $materialName = (string) ($payload['material_name'] ?? $existing['type_materials']);
            $brandId = $this->getOrCreateId($pdo, 'marques', 'nom_marques', 'id_marques', $brandName);
            $materialId = $this->getOrCreateId($pdo, 'materials', 'type_materials', 'id_materials', $materialName);

            $stmt = $pdo->prepare(
                'UPDATE public.spools SET
                    nfc_id = :nfc_id,
                    color_name = :color_name,
                    initial_weight = :initial_weight,
                    empty_spool_weight = :empty_spool_weight,
                    diametre = :diametre,
                    temperature_imp = :temperature_imp,
                    temperature_table = :temperature_table,
                    debit = :debit,
                    pressure_advance = :pressure_advance,
                    vit_volum_max = :vit_volum_max,
                    vit_imp = :vit_imp,
                    id_marques = :id_marques,
                    id_materials = :id_materials
                 WHERE id_spools = :id_spools'
            );

            $stmt->execute([
                'nfc_id' => (string) ($payload['nfc_id'] ?? $existing['nfc_id']),
                'color_name' => (string) ($payload['color_name'] ?? $existing['color_name']),
                'initial_weight' => (float) ($payload['initial_weight'] ?? $existing['initial_weight']),
                'empty_spool_weight' => (float) ($payload['empty_spool_weight'] ?? $existing['empty_spool_weight']),
                'diametre' => (float) ($payload['diametre'] ?? $existing['diametre']),
                'temperature_imp' => (float) ($payload['temperature_imp'] ?? $existing['temperature_imp']),
                'temperature_table' => (float) ($payload['temperature_table'] ?? $existing['temperature_table']),
                'debit' => (float) ($payload['debit'] ?? $existing['debit']),
                'pressure_advance' => (float) ($payload['pressure_advance'] ?? $existing['pressure_advance']),
                'vit_volum_max' => (float) ($payload['vit_volum_max'] ?? $existing['vit_volum_max']),
                'vit_imp' => (float) ($payload['vit_imp'] ?? $existing['vit_imp']),
                'id_marques' => $brandId,
                'id_materials' => $materialId,
                'id_spools' => $spoolId,
            ]);

            $pdo->commit();

            return $this->getById($spoolId);
        } catch (\Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    public function deleteSpool(int $spoolId): bool
    {
        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare('DELETE FROM public.spools WHERE id_spools = :id_spools');
        $stmt->execute(['id_spools' => $spoolId]);

        return $stmt->rowCount() > 0;
    }

    public function cloneSpool(int $spoolId, ?string $nfcId = null): ?array
    {
        $existing = $this->getById($spoolId);
        if ($existing === null) {
            return null;
        }

        $pdo = $this->connectionFactory->create();
        $pdo->beginTransaction();

        try {
            $stmt = $pdo->prepare(
                'INSERT INTO public.spools (
                    nfc_id, color_name, initial_weight, empty_spool_weight,
                    diametre, temperature_imp, temperature_table, debit,
                    pressure_advance, vit_volum_max, vit_imp, id_marques, id_materials
                ) VALUES (
                    :nfc_id, :color_name, :initial_weight, :empty_spool_weight,
                    :diametre, :temperature_imp, :temperature_table, :debit,
                    :pressure_advance, :vit_volum_max, :vit_imp, :id_marques, :id_materials
                ) RETURNING id_spools'
            );

            $stmt->execute([
                'nfc_id' => $nfcId ?? '',
                'color_name' => (string) $existing['color_name'],
                'initial_weight' => (float) $existing['initial_weight'],
                'empty_spool_weight' => (float) $existing['empty_spool_weight'],
                'diametre' => (float) $existing['diametre'],
                'temperature_imp' => (float) $existing['temperature_imp'],
                'temperature_table' => (float) $existing['temperature_table'],
                'debit' => (float) $existing['debit'],
                'pressure_advance' => (float) $existing['pressure_advance'],
                'vit_volum_max' => (float) $existing['vit_volum_max'],
                'vit_imp' => (float) $existing['vit_imp'],
                'id_marques' => (int) $existing['id_marques'],
                'id_materials' => (int) $existing['id_materials'],
            ]);

            $newId = (int) $stmt->fetchColumn();
            $pdo->commit();

            return $this->getById($newId);
        } catch (\Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
    }

    public function getStatsByMaterial(): array
    {
        $sql = <<<SQL
            SELECT
                mat.type_materials,
                SUM(s.initial_weight) AS poids_total
            FROM public.spools s
            JOIN public.materials mat ON s.id_materials = mat.id_materials
            GROUP BY mat.type_materials
            ORDER BY poids_total DESC
        SQL;

        return $this->runQuery($sql);
    }

    public function getStatsByProject(): array
    {
        $sql = <<<SQL
            SELECT
                project_name,
                SUM(weight_used) AS total_consomme
            FROM public.usage_logs
            GROUP BY project_name
            ORDER BY total_consomme DESC
            LIMIT 10
        SQL;

        return $this->runQuery($sql);
    }

    public function getStatsByMonth(): array
    {
        $sql = <<<SQL
            SELECT
                DATE_TRUNC('month', print_date) AS mois,
                SUM(weight_used) AS total_consomme
            FROM public.usage_logs
            GROUP BY mois
            ORDER BY mois
        SQL;

        return $this->runQuery($sql);
    }

    public function getById(int $spoolId): ?array
    {
        $sql = <<<SQL
            SELECT
                s.*,
                m.nom_marques,
                mat.type_materials,
                (s.initial_weight - COALESCE(SUM(u.weight_used), 0)) AS poids_restant
            FROM public.spools s
            JOIN public.marques m ON s.id_marques = m.id_marques
            JOIN public.materials mat ON s.id_materials = mat.id_materials
            LEFT JOIN public.usage_logs u ON s.id_spools = u.id_spools
            WHERE s.id_spools = :id_spools
            GROUP BY s.id_spools, m.id_marques, m.nom_marques, mat.id_materials, mat.type_materials
            LIMIT 1
        SQL;

        $result = $this->runQuery($sql, ['id_spools' => $spoolId]);

        return $result[0] ?? null;
    }

    private function getOrCreateId(
        PDO $pdo,
        string $table,
        string $column,
        string $idColumn,
        string $value
    ): int {
        $normalized = trim($value);
        $select = $pdo->prepare(sprintf('SELECT %s FROM public.%s WHERE %s ILIKE :value LIMIT 1', $idColumn, $table, $column));
        $select->execute(['value' => $normalized]);
        $existingId = $select->fetchColumn();
        if ($existingId !== false) {
            return (int) $existingId;
        }

        $insert = $pdo->prepare(sprintf('INSERT INTO public.%s (%s) VALUES (:value) RETURNING %s', $table, $column, $idColumn));
        $insert->execute(['value' => $normalized]);

        return (int) $insert->fetchColumn();
    }

    private function runQuery(string $sql, array $params = []): array
    {
        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
