<?php

namespace App\EventSubscriber;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\KernelEvents;

class ApiTokenSubscriber implements EventSubscriberInterface
{
    private string $apiToken;

    public function __construct(string $apiToken)
    {
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

        if ($request->getMethod() === 'OPTIONS' || $path === '/api/health') {
            return;
        }

        $authorization = $request->headers->get('Authorization', '');
        $expectedHeader = 'Bearer '.$this->apiToken;

        if (!hash_equals($expectedHeader, $authorization)) {
            $event->setResponse(new JsonResponse(['message' => 'Unauthorized'], 401));
        }
    }
}
