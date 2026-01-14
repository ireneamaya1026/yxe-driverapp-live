<?php

use App\Http\Controllers\Auth\AuthenticationController;
use App\Http\Controllers\TransactionController;
use Illuminate\Http\Middleware\HandleCors;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;
use App\Http\Controllers\FetchDataController;

Route::middleware([HandleCors::class])->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    })->middleware('auth:sanctum');

    Route::get('/test', function()  {
        return response([
            'message' => 'Api is working'
        ], 200);
    });
    Route::post('/createTransaction', [TransactionController::class, 'create'])->middleware('api');
    // Route::post('createTransaction', [TransactionController::class, 'create']);
    Route::post('loginDriver', [AuthenticationController::class, 'loginDriver']);
    Route::post('register', [AuthenticationController::class, 'register']);
    Route::post('login', [AuthenticationController::class, 'login']);
    Route::post('logout', [AuthenticationController::class, 'logout'])->middleware('auth:sanctum');
    Route::put('update', [AuthenticationController::class, 'updateProfile'])->middleware('auth:sanctum');
    Route::get('/odoo/users', [AuthenticationController::class, 'getUser']);
    Route::get('/odoo/booking/today', [FetchDataController::class, 'getTodayBooking']);
    Route::get('/odoo/history', [FetchDataController::class, 'getHistory']);
    Route::get('/odoo/reason', [FetchDataController::class, 'getRejectionReason']);
    Route::post('/odoo/{transactionId}/status', [TransactionController::class, 'updateStatus']);
    Route::post('/odoo/reject-booking', [TransactionController::class, 'rejectBooking']);
    Route::get('/odoo/reject_vendor', [TransactionController::class, 'rejectVendor']);
    Route::post('/odoo/pod-accepted-to-ongoing', [TransactionController::class, 'uploadPOD']);
    Route::post('/odoo/pod-ongoing-to-complete', [TransactionController::class, 'uploadPOD_sec']);

    Route::get('/odoo/booking/ongoing', [FetchDataController::class, 'getOngoingBooking']);
    Route::get('/odoo/booking/history', [FetchDataController::class, 'getHistoryBooking']);
    Route::get('/odoo/booking/all-bookings', [FetchDataController::class, 'getAllBooking']);
    Route::get('/odoo/booking/all-history', [FetchDataController::class, 'getAllHistory']);

    //Fetch transaction details for second screen
    Route::get('/odoo/booking/transaction_details/{id}', [FetchDataController::class, 'getSecondScreenData']);
    Route::get('/odoo/booking/history_details/{id}', [FetchDataController::class, 'getHistoryDetails']);

    Route::post('/odoo/notify', [TransactionController::class, 'notifyShipperConsignee']);

    Route::get('/odoo/booking/reassignment', [FetchDataController::class, 'reassignment']);

});