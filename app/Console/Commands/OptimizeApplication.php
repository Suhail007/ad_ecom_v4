<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class OptimizeApplication extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'app:optimize';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Optimize the application for production';

    /**
     * Execute the console command.
     *
     * @return int
     */
    public function handle()
    {
        $this->info('Starting application optimization...');

        // Clear all caches
        $this->callSilent('cache:clear');
        $this->callSilent('config:clear');
        $this->callSilent('route:clear');
        $this->callSilent('view:clear');
        $this->callSilent('event:clear');
        
        // Cache configurations
        $this->call('config:cache');
        $this->call('route:cache');
        $this->call('view:cache');
        $this->call('event:cache');
        
        // Optimize the framework
        $this->call('optimize');
        
        // Clear and warm the model cache
        if (class_exists('App\\Models\\Model')) {
            $this->call('modelCache:clear');
            $this->call('modelCache:create');
        }
        
        // Clear and rebuild the sitemap
        if (file_exists(public_path('sitemap.xml'))) {
            unlink(public_path('sitemap.xml'));
        }
        
        // Optimize database tables
        $this->optimizeDatabase();
        
        // Clear and warm the cache
        Cache::flush();
        
        // Preload frequently used routes and views
        $this->warmCache();
        
        $this->info('Application optimization completed successfully!');
        
        return 0;
    }
    
    /**
     * Optimize database tables
     */
    protected function optimizeDatabase()
    {
        $tables = DB::select('SHOW TABLES');
        
        $this->info('Optimizing database tables...');
        $bar = $this->output->createProgressBar(count($tables));
        
        foreach ($tables as $table) {
            $tableName = array_values((array)$table)[0];
            DB::statement("ANALYZE TABLE `{$tableName}`");
            DB::statement("OPTIMIZE TABLE `{$tableName}`");
            $bar->advance();
        }
        
        $bar->finish();
        $this->newLine();
    }
    
    /**
     * Warm up the cache with frequently accessed data
     */
    protected function warmCache()
    {
        $this->info('Warming up cache...');
        
        // Add your frequently accessed routes and data here
        $routes = [
            '/api/list',
            // Add more routes as needed
        ];
        
        $client = new \GuzzleHttp\Client();
        $baseUrl = config('app.url');
        
        foreach ($routes as $route) {
            try {
                $client->get($baseUrl . $route);
                $this->info("Warmed up: {$route}");
            } catch (\Exception $e) {
                $this->warn("Failed to warm up {$route}: " . $e->getMessage());
            }
        }
    }
}
