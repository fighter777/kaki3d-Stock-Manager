<?php

namespace App\Command;

use App\Repository\AuthRepository;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;

class AuthInitCommand extends Command
{
    protected static $defaultName = 'app:auth:init';
    protected static $defaultDescription = 'Initialise les tables utilisateurs et tokens API.';

    private AuthRepository $authRepository;

    public function __construct(AuthRepository $authRepository)
    {
        parent::__construct();
        $this->authRepository = $authRepository;
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $this->authRepository->initSchema();
        $output->writeln('<info>Schema auth initialise.</info>');

        return Command::SUCCESS;
    }
}

