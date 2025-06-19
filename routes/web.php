<?php

use App\Http\Controllers\OrderPdfController;
use App\Http\Controllers\HealthCheckController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "web" middleware group. Make something great!
|
*/

// Health check endpoint
Route::get('/health', [HealthCheckController::class, '__invoke']);

Route::get('/', function () {
    return view('welcome');
});
Route::get('/order/{id}/pdf', [OrderPdfController::class, 'generateOrderPdf']);
