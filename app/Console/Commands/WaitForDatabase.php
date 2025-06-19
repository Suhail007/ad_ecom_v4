<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Exception;

class WaitForDatabase extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'db:wait {--timeout=60 : The maximum number of seconds to wait} {--sleep=2 : The number of seconds to wait between attempts}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Wait for the database to be ready';

    /**
     * Execute the console command.
     *
     * @return int
     */
    public function handle()
    {
        $timeout = (int) $this->option('timeout');
        $sleep = (int) $this->option('sleep');
        $start = time();
        $connected = false;
        $maxAttempts = $timeout / $sleep;
        $attempt = 0;

        $this->info("Waiting for database connection... (Timeout: {$timeout}s)");

        while (!$connected && (time() - $start < $timeout)) {
            $attempt++;
            $this->line("Attempt {$attempt}/{$maxAttempts}...");

            try {
                DB::connection()->getPdo();
                $connected = true;
                $this->info('Successfully connected to the database!');
                return 0;
            } catch (\Exception $e) {
                $this->warn("Database connection failed: " . $e->getMessage());
                if (time() - $start + $sleep >= $timeout) {
                    break;
                }
                sleep($sleep);
            }
        }

        $this->error("Failed to connect to the database after {$timeout} seconds");
        return 1;
    }
}
