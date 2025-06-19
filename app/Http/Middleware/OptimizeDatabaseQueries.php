<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

class OptimizeDatabaseQueries
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure  $next
     * @return mixed
     */
    public function handle($request, Closure $next)
    {
        // Enable query logging in non-production for debugging
        if (app()->environment('local')) {
            DB::enableQueryLog();
        }

        // Add response caching for GET requests
        if ($request->isMethod('get')) {
            $cacheKey = 'route_' . sha1($request->url() . '?' . http_build_query($request->all()));
            
            // Cache for 5 minutes (300 seconds)
            return Cache::remember($cacheKey, 300, function () use ($request, $next) {
                return $next($request);
            });
        }

        $response = $next($request);

        // Log slow queries in production
        if (app()->environment('production') && $queries = DB::getQueryLog()) {
            $slowQueries = array_filter($queries, function($query) {
                return $query['time'] > 100; // Log queries slower than 100ms
            });

            if (!empty($slowQueries)) {
                \Log::warning('Slow queries detected', [
                    'url' => request()->fullUrl(),
                    'queries' => $slowQueries,
                    'count' => count($slowQueries)
                ]);
            }
        }

        return $response;
    }
}
