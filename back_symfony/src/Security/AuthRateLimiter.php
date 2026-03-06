<?php

namespace App\Security;

use Psr\Cache\CacheItemPoolInterface;

class AuthRateLimiter
{
    private CacheItemPoolInterface $cache;

    public function __construct(CacheItemPoolInterface $cache)
    {
        $this->cache = $cache;
    }

    /**
     * @return array{allowed: bool, retry_after_seconds: int}
     */
    public function consume(string $scope, string $identifier, int $limit, int $windowSeconds): array
    {
        $cacheKey = $this->buildKey($scope, $identifier);
        $now = time();

        $item = $this->cache->getItem($cacheKey);
        $state = $item->isHit() ? $item->get() : null;
        if (!is_array($state) || !isset($state['start'], $state['count'])) {
            $state = ['start' => $now, 'count' => 0];
        }

        $elapsed = $now - (int) $state['start'];
        if ($elapsed >= $windowSeconds) {
            $state = ['start' => $now, 'count' => 0];
            $elapsed = 0;
        }

        if ((int) $state['count'] >= $limit) {
            return [
                'allowed' => false,
                'retry_after_seconds' => max(1, $windowSeconds - $elapsed),
            ];
        }

        $state['count'] = (int) $state['count'] + 1;
        $item->set($state);
        $item->expiresAfter($windowSeconds);
        $this->cache->save($item);

        return [
            'allowed' => true,
            'retry_after_seconds' => 0,
        ];
    }

    private function buildKey(string $scope, string $identifier): string
    {
        return 'auth_rate_'.sha1($scope.'|'.$identifier);
    }
}

