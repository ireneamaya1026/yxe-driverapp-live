<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Models\User;
use App\Models\Partners;
use Exception;
use Illuminate\Container\Attributes\Auth;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\JsonResponse;
use App\Http\Requests\LoginDriverRequest;
use Illuminate\Support\Facades\Log;
use PhpXmlRpc\PhpXmlRpcClient;
use PhpXmlRpc\Client;
use PhpXmlRpc\Value;
use PhpXmlRpc\Request as XmlRpcRequest;
use Ripcord\Ripcord; 

class AuthenticationController extends Controller
{

    protected $db = 'yxe-odoo-yxe-live-production-18245399';
    protected $url = "https://yxe-odoo-yxe-live.odoo.com/jsonrpc";

    public function getOdooUsers()
    {
        // Fetch all users
        $users = User::all();
        // Optionally, filter specific users
        $filteredUsers = User::where('active', '=', true)->get();

        return response()->json([
            'users' => $users,
            'active_users' => $filteredUsers,
        ]);
    }
    public function register(RegisterRequest $request){
        $validatedData = $request->validated();
        if ($request->hasFile('picture')) {
            // Store the image and get the file path
            $path = $request->file('picture')->store('profile_pictures', 'public');
            $validatedData['picture'] = $path; // Save the path in validated data
        }
        $userData = [
            'name' => $validatedData['name'],
            'email' => $validatedData['email'],
            'mobile' => $validatedData['mobile'],
            'company_code' => $validatedData['company_code'] ?? null, // Allow null if not provided
            'password' => Hash::make($validatedData['password'],),
            'picture' => $validatedData['picture'] ?? null,
        ];
        Log::info('User registration data:', $userData);
        try {
            $user = User::create($userData);
            $token = $user->createToken('wheelzrus')->plainTextToken;
        
            return response([
                'user' => $user,
                'token' => $token
            ], 201);
        } catch (\Exception $e) {
            Log::error('User creation failed: ' . $e->getMessage());
            return response()->json(['error' => 'User registration failed.'], 500);
        }
    }
    
    public function authenticateOdooUser($credentials)
    {
        $username = $credentials['email'];  // Odoo login field
        $password = $credentials['password']; // Odoo password
       

        $url = $this->url;
        $db = $this->db;
       
        
        $jsonrequest = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "common",
                "method" => "authenticate",
                "args" => [
                    $db,
                    $username,
                    $password,
                    []
                ]
            ],
            "id" => 1
        ];

        $options = [
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($jsonrequest),
                "ignore_errors" => true,
                'timeout' => 5
            ],
        ];

        $context = stream_context_create($options);
        $response = file_get_contents($url, false, $context);

        if($response === false) {
            Log::error("🚨 Authentication failed: No response from Odoo server.");
            return 0;
        }
       
       

        $result = json_decode($response, true);
       return $result['result'] ?? 0; // Return UID or 0 if not found
       
    }

    public function getUser($username,$uid, $odooPassword)
    {
        $url = $this->url;
        $db = $this->db;

        Log::info("🔍 Searching for Odoo user with email: $username");
        
        Log::info("✅ Odoo Authentication UID:", ['uid' => $uid]);
        if (!$uid || $uid <= 0) {
            Log::error("🚨 Invalid UID received. Authentication failed.");
            return null;
        }
       
        $jsonrequest = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "object",
                "method" => "execute_kw",
                "args" => [
                    $db,
                    $uid,
                    $odooPassword,
                    "res.users",
                    "check_access_rights",
                    ["read"],
                    ["raise_exception" => false]
                ]
            ],
            "id" => 1
        ];

        $options = [
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($jsonrequest),
                "ignore_errors" => true,
            ],
        ];
        $jsoncontext = stream_context_create($options);
        $jsonresponse = file_get_contents($url, false, $jsoncontext);

        if($jsonresponse === false) {
            Log::error("🚨 Authentication failed: No response from Odoo server.");
            return response()->json(['error' => 'Access Denied'], 403);
        }
        Log::debug("🪵 Raw JSON response: " . $jsonresponse);

        $jsonresult = json_decode($jsonresponse, true);

        Log::info("🔍JSON Raw Response: ", ["response" => $jsonresult]);

        if(!isset($jsonresult['result']) || $jsonresult['result'] === false) {
            Log::error("🚨 UID {$uid} still cannot read `res.users`. Permission issue?");
            return response()->json(["error" => "Access Denied"], 403);
        } else {
            Log::info("✅ UID {$uid} can read `res.users`.");
        }

        
        $data = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "object",  // ✅ Add "service"
                "method" => "execute_kw",
                "args" => [
                    $db,  // ✅ Ensure DB name is correct
                    $uid, // ✅ Ensure UID is not empty
                    $odooPassword, // ✅ Ensure password or API key is correct
                    "res.users",  // ✅ Correct model name
                    "search_read",  // ✅ Correct method
                    [[["login", "=", $username]]],  // ✅ Ensure correct filtering
                    ["fields" => ["id", "login", "partner_id","image_1920"]] // ✅ Ensure correct fields
                ]
            ],
            "id" => 1
        ];
        
        $options = [
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($data),
            ],
        ];
        
        $context = stream_context_create($options);
        $response = file_get_contents($url, false, $context);
        $result = json_decode($response, true);
        
        if (!is_array($result) || !isset($result['result'])) {
            Log::error("❌ Invalid Odoo response: ", ["response" => $result]);
            return null;
        }
        
        $userList = $result['result'];
        
        if (!is_array($userList)) {
            Log::error("❌ Unexpected response type: ", ["response" => $userList]);
            return null;
        }
        
        foreach ($userList as $user) {
            Log::info("✅ Found User: ", ["id" => $user['id'], "login" => $user['login']]);
        }
        if (!empty($userList)) {
            $user = $userList[0]; // Assuming you only need the first user found
            $partnerId = $user['partner_id'][0] ?? null; // Extract partner ID
        
            if ($partnerId) {
                Log::info("✅ Partner ID found: $partnerId");
        
                // 🔍 Search res.partner to check if this partner has driver access
                $partnerSearchData = [
                    "jsonrpc" => "2.0",
                    "method" => "call",
                    "params" => [
                        "service" => "object",
                        "method" => "execute_kw",
                        "args" => [
                            $db,
                            $uid,
                            $odooPassword,
                            "res.partner",
                            "search_read",
                            [[["id", "=", $partnerId]]], // 🔍 Search by Partner ID
                            ["fields" => ["id", "name", "driver_access"]] // Include relevant fields
                        ]
                    ],
                    "id" => 2
                ];
        
                $options = [
                    "http" => [
                        "header" => "Content-Type: application/json",
                        "method" => "POST",
                        "content" => json_encode($partnerSearchData),
                    ],
                ];
        
                $context = stream_context_create($options);
                $response = file_get_contents($url, false, $context);
                $partnerResult = json_decode($response, true);
        
                if (isset($partnerResult['result']) && !empty($partnerResult['result'])) {
                    $partner = $partnerResult['result'][0];
                    $isDriver = $partner['driver_access'] ?? false; // Replace with actual driver field
        
                    if ($isDriver) {
                        Log::info("✅ Partner {$partner['name']} is a driver.");
                    } else {
                        Log::warning("❌ Partner {$partner['name']} is NOT a driver.");
                    }
                } else {
                    Log::error("❌ No partner record found for ID: $partnerId");
                }
            } else {
                Log::error("❌ No Partner ID found for user.");
            }
        }
        return $user;
    }
    

    public function login(Request $request){
        $credentials = $request->only('email', 'password');
        $odooPassword = $credentials['password'];
        $url = $this->url;
        $db = $this->db;
        
        //Check authentication
        $uid = $this->authenticateOdooUser($credentials);
       
        if($uid == 0){
            return response()->json([
                'success' => false,
                'message' => 'Invalid email or password credentials',
            ], 401);
        }
        //Get user data
        $user = $this->getUser($credentials['email'],$uid, $odooPassword);
        if(!$user){
            return response()->json(['message' => 'User not found'], 404);
        }

        $partnerId = $user['partner_id'][0] ?? null;

        if (!$partnerId) {
            return response()->json(['message' => 'Partner ID not found'], 404);
        }

        // ✅ Fetch `driver_access` From `res.partner`
        $partnerSearchData = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "object",
                "method" => "execute_kw",
                "args" => [
                    $db,
                    $uid,
                    $odooPassword,
                    "res.partner",
                    "search_read",
                    [[["id", "=", $partnerId]]],
                    ["fields" => ["id", "name", "driver_access", "mobile","phone","license_number","license_expiry","license_status"]] // ✅ Fetch `driver_access`
                ]
            ],
            "id" => 2
        ];

        $options = [
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($partnerSearchData),
            ],
        ];

        $context = stream_context_create($options);
        $response = file_get_contents($url, false, $context);
        $partnerResult = json_decode($response, true);

        // ✅ Debug: Check if `driver_access` exists in the response
        // dd($partnerResult); // Stop execution and check output

        if (isset($partnerResult['result']) && !empty($partnerResult['result'])) {
            $partner = $partnerResult['result'][0];
            $isDriver = $partner['driver_access'] ?? false;
            $mobile = $partner['mobile'] ?? null;
            $phone = $partner['phone'] ?? null;
            $licenseNumber = $partner['license_number'] ?? null;
            $licenseExpiry = $partner['license_expiry'] ?? null;
            $licenseStatus = $partner['license_status'] ?? null;
            

            // if ($isDriver) {
            //     Log::info("✅ Partner {$partner['name']} is a driver.");
            // } else {
            //     Log::warning("❌ Partner {$partner['name']} is NOT a driver.");
            // }
        } else {
            Log::error("❌ No partner record found for ID: $partnerId");
            return response()->json(['message' => 'Partner record not found'], 404);
        }

        // ✅ Step 3: Block Non-Drivers
        if (!$isDriver) {
            return response()->json([
                'success' => false,
                'message' => 'Access denied. Only drivers can log in.'
            ], 403);
        }
       
        
        return response()->json([
            'status' => 'success',
            'message' => 'User authenticated successfully',
            'user' => $user,
            'uid' => $uid,
            'password' => $odooPassword,
            'mobile' => $mobile,
            'phone' => $phone,
            'license_number' => $licenseNumber,
            'license_expiry' => $licenseExpiry,
            'license_status' => $licenseStatus,
        
        ], 200);
    }


    // public function logout(Request $request){
    //     if ($user = $request->user()) {
    //         $user->currentAccessToken()->delete();

    //         return response()->json(['message' => 'Logged out successfully'], 200);
    //     }

    //     return response()->json(['message' => 'No authenticated user'], 401);
    // }

    // public function updateProfile(Request $request) {
    //     $user = $request->user();
        
    //     // Validate the incoming request data
    //     $validator = Validator::make($request->all(), [
    //         'name' => 'sometimes|string|max:255',
    //         'email' => 'sometimes|email|unique:users,email,' . $user->id,
    //         'mobile' => 'sometimes|string|unique:users,mobile,' . $user->id,
    //         'company_code' => 'nullable|string|min:6',
    //         'password' => 'sometimes|string|min:8|confirmed',
    //         'picture' => 'nullable|image|mimes:jpeg,png,jpg,gif,svg|max:6144',
    //     ]);
        
    //     if ($validator->fails()) {
    //         return response()->json($validator->errors(), 422);
    //     }
    
    //     // Update other fields if present
    //     if ($request->has('name')) {
    //         $user->name = $request->input('name');
    //     }
    
    //     if ($request->has('email')) {
    //         $user->email = $request->input('email');
    //     }
    
    //     if ($request->has('mobile')) {
    //         $user->mobile = $request->input('mobile');
    //     }
    
    //     if ($request->has('company_code')) {
    //         $user->company_code = $request->input('company_code');
    //     }
    
    //     if ($request->has('password')) {
    //         $user->password = Hash::make($request->input('password'));
    //     }
    
    //     // Check if a new picture was uploaded
    //     if ($request->hasFile('picture')) {
    //         // Delete the old picture if it exists
    //         if ($user->picture) {
    //             Storage::disk('public')->delete($user->picture);
    //         }
    
    //         // Store the new picture and assign the path to the user
    //         $path = $request->file('picture')->store('profile_pictures', 'public');
    //         $user->picture = $path; // Save the new picture path
    //     }
    
    //     // Save updated user data
    //     try {
    //         $user->save();
    //         return response()->json([
    //             'message' => 'Profile updated successfully',
    //             'user' => $user
    //         ], 200);
    //     } catch (\Exception $e) {
    //         Log::error('Profile update failed: ' . $e->getMessage());
    //         return response()->json(['error' => 'Profile update failed.'], 500);
    //     }
    // }
    
}