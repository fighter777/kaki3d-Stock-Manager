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

    private function runQuery(string $sql, array $params = []): array
    {
        $pdo = $this->connectionFactory->create();
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);

        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
}
