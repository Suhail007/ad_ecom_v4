<?php

namespace App\Providers;

// use Automattic\WooCommerce\HttpClient\Request;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Queue\Middleware\RateLimited;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Event;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('login', function (Request $request) {
            return Limit::perMinute(5)->by($request->input('user_email'));
        });

        Event::listen('Illuminate\Routing\Events\RouteMatched', function () {
            $start = microtime(true);
            app()->terminating(function () use ($start) {
                $duration = round((microtime(true) - $start) * 1000, 2);
                header("Server-Timing: total;dur={$duration}");
            });
        });
    }
}
