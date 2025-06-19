<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Cache;

class HealthCheckController extends Controller
{
    /**
     * Health check endpoint
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function __invoke(Request $request): JsonResponse
    {
        $status = 200;
        $checks = [
            'application' => $this->checkApplication(),
            'database' => $this->checkDatabase(),
            'cache' => $this->checkCache(),
            'redis' => $this->checkRedis(),
        ];

        // If any check failed, set status to 503
        if (in_array(false, array_column($checks, 'healthy'), true)) {
            $status = 503;
        }

        return response()->json([
            'status' => $status === 200 ? 'ok' : 'error',
            'timestamp' => now()->toDateTimeString(),
            'checks' => $checks,
        ], $status);
    }

    /**
     * Check application status
     *
     * @return array
     */
    protected function checkApplication(): array
    {
        return [
            'healthy' => true,
            'message' => 'Application is running',
            'version' => app()->version(),
            'environment' => app()->environment(),
            'debug' => config('app.debug'),
        ];
    }

    /**
     * Check database connection
     *
     * @return array
     */
    protected function checkDatabase(): array
    {
        try {
            DB::connection()->getPdo();
            
            return [
                'healthy' => true,
                'message' => 'Database connection successful',
                'driver' => config('database.default'),
                'database' => config("database.connections." . config('database.default') . ".database"),
            ];
        } catch (\Exception $e) {
            return [
                'healthy' => false,
                'message' => 'Database connection failed: ' . $e->getMessage(),
            ];
        }
    }

    /**
     * Check cache connection
     *
     * @return array
     */
    protected function checkCache(): array
    {
        try {
            $key = 'health-check-' . time();
            $value = 'test';
            
            Cache::put($key, $value, 10);
            $cached = Cache::get($key) === $value;
            
            return [
                'healthy' => $cached,
                'message' => $cached ? 'Cache is working' : 'Cache test failed',
                'driver' => config('cache.default'),
            ];
        } catch (\Exception $e) {
            return [
                'healthy' => false,
                'message' => 'Cache connection failed: ' . $e->getMessage(),
            ];
        }
    }

    /**
     * Check Redis connection
     *
     * @return array
     */
    protected function checkRedis(): array
    {
        try {
            Redis::ping();
            
            return [
                'healthy' => true,
                'message' => 'Redis connection successful',
                'client' => config('database.redis.client'),
                'host' => config('database.redis.default.host'),
                'port' => config('database.redis.default.port'),
            ];
        } catch (\Exception $e) {
            return [
                'healthy' => false,
                'message' => 'Redis connection failed: ' . $e->getMessage(),
            ];
        }
    }
}
