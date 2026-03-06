<?php

namespace App\EventSubscriber;

use App\Repository\AuthRepository;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\KernelEvents;

class ApiTokenSubscriber implements EventSubscriberInterface
{
    private AuthRepository $authRepository;
    private string $apiToken;

    public function __construct(AuthRepository $authRepository, string $apiToken)
    {
        $this->authRepository = $authRepository;
        $this->apiToken = $apiToken;
    }

    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::REQUEST => ['onKernelRequest', 20],
        ];
    }

    public function onKernelRequest(RequestEvent $event): void
    {
        if (!$event->isMainRequest()) {
            return;
        }

        $request = $event->getRequest();
        $path = $request->getPathInfo();

        if (!str_starts_with($path, '/api')) {
            return;
        }

        if ($request->getMethod() === 'OPTIONS' || in_array($path, ['/api/health', '/api/auth/register', '/api/auth/login'], true)) {
            return;
        }

        $authorization = trim((string) $request->headers->get('Authorization', ''));
        if (!str_starts_with($authorization, 'Bearer ')) {
            $event->setResponse(new JsonResponse(['message' => 'Unauthorized'], 401));
            return;
        }

        $token = trim(substr($authorization, 7));
        if ($token === '') {
            $event->setResponse(new JsonResponse(['message' => 'Unauthorized'], 401));
            return;
        }

        // Temporary bootstrap: the static token from env remains accepted.
        if ($token === $this->apiToken) {
            return;
        }

        if (!$this->authRepository->isTokenValid($token)) {
            $event->setResponse(new JsonResponse(['message' => 'Unauthorized'], 401));
        }
    }
}
