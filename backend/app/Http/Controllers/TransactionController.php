<?php

namespace App\Http\Controllers;
use Illuminate\Support\Facades\Log;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Models\Transaction;
use App\Models\RejectionReason;
use App\Models\TransactionImage;
use PhpXmlRpc\Client;
use PhpXmlRpc\Value;
use PhpXmlRpc\Request as XmlRpcRequest;
use Ripcord\Ripcord; 
use Illuminate\Support\Facades\Http;
use GuzzleHttp\Guzzle;
use Carbon\Carbon;



class TransactionController extends Controller
{
    protected $url = "https://jralejandria-alpha-dev-yxe.odoo.com";
    protected $db = 'jralejandria-alpha-dev-yxe1-production-alpha-26901548';
    // protected $odoo_url = "http://192.168.76.205:8080/odoo/jsonrpc";
    protected $odoo_url = "https://jralejandria-alpha-dev-yxe.odoo.com/jsonrpc";

   
   
    public function updateStatus(Request $request ,$transactionId)
    {
        // Log::info("Transaction ID is {$transactionId}");
        Log::info("Incoming update request", ['data' => $request->all()]);

        $validated = $request->validate([
            'requestNumber' => 'required|string',
            'requestStatus' => 'required|string',
            'timestamp' => 'required|date',
        ]);
       
        $url = $this->url;
        $db = $this->db;

        $uid = $request->query('uid') ;
        $odooPassword = $request->header('password');
        
        if (!$uid) {
            return response()->json(['success' => false, 'message' => 'UID is required'], 400);
        }
        
        
        $odooUrl = $this->odoo_url;
        $updateStatus = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "object",
                "method" => "execute_kw",
                "args" => [
                    $db, 
                    $uid, 
                    $odooPassword, 
                    "dispatch.manager", 
                    "search_read",
                    [[["id", "=", $transactionId],
                    '|','|','|',
                    ['de_request_no', '=', $validated['requestNumber']],
                    ['dl_request_no', '=', $validated['requestNumber']],
                    ['pe_request_no', '=', $validated['requestNumber']],
                    ['pl_request_no', '=', $validated['requestNumber']],
                    ]],  // Search by Request Number
                    ["fields" => [
                        "id", "name","de_request_status", "pl_request_status", "dl_request_status", "pe_request_status",
                        "de_request_no", "pl_request_no", "dl_request_no", "pe_request_no"
                    ]]
                ]
            ],
            "id" => 1
        ];
    
        $statusResponse = json_decode(file_get_contents($odooUrl, false, stream_context_create([
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($updateStatus),
            ],
        ])), true);
    
        if (!isset($statusResponse['result']) || empty($statusResponse['result'])) {
            Log::error("❌ No data on this ID", ["response" => $statusResponse]);
            return response()->json(['success' => false, 'message' => 'Data not found'], 404);
        }

        $transactionIds = $statusResponse['result'][0] ?? null;
   
      
        if (!$transactionIds || !is_array($transactionIds)) {
            Log::error("Incorrect structure", ["response" => $statusResponse]);
            return response()->json(['success' => false, 'message' => 'Transaction structure is incorrect.'], 404);
        }

        $updateField = null;

        $requestNumber = (string) $validated['requestNumber'];

        // Debugging log
        Log::info("Transaction Data", ["transaction" => $transactionIds, "requestNumber" => $requestNumber]);
        

        if (isset($transactionIds['de_request_no']) && (string) $transactionIds['de_request_no'] === $validated['requestNumber']){
            $updateField = "de_request_status";
        }elseif (isset($transactionIds['dl_request_no']) && (string) $transactionIds['dl_request_no'] === $validated['requestNumber']){
            $updateField = "dl_request_status";
        }elseif (isset($transactionIds['pe_request_no']) && (string) $transactionIds['pe_request_no'] === $validated['requestNumber']){
            $updateField = "pe_request_status";
        }elseif (isset($transactionIds['pl_request_no']) && (string) $transactionIds['pl_request_no'] === $validated['requestNumber']){
            $updateField = "pl_request_status";
        }

        if (!$updateField) {
            Log::error("❌ Request number doesn't match any field", [
                "requestNumber" => $requestNumber,
                "de_request_no" => $transactionIds['de_request_no'] ?? 'N/A',
                "dl_request_no" => $transactionIds['dl_request_no'] ?? 'N/A',
                "pe_request_no" => $transactionIds['pe_request_no'] ?? 'N/A',
                "pl_request_no" => $transactionIds['pl_request_no'] ?? 'N/A'
            ]);
            return response()->json(['success' => false, 'message' => 'Invalid request number'], 400);
        }

        $updatePending = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "object",
                "method" => "execute_kw",
                "args" => [
                    $db, 
                    $uid, 
                    $odooPassword, 
                    "dispatch.manager", 
                    "write",
                    [
                        [$transactionIds['id']],
                        [
                            $updateField => $request->requestStatus,
                        ]
                    ]
                ]
            ],
            "id" => 2
        ];

        $updateResponse = json_decode(file_get_contents($odooUrl,false,stream_context_create([
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($updatePending),
            ]
        ])), true);

        if (isset($updateResponse['result']) && $updateResponse['result']) {
            return response()->json(['success' => true, 'message'=>'Transaction status updated succcessfully!']);
        }else{
            Log::error("Failed to update status", ["response" => $updateResponse]);
            return response()->json(['success' => false,'message'=>'Failed to update transaction'], 500);
        }
       
        return response()->json($statusResponse);
    }

    private function handleDispatchRequest(Request $request)
    {
        $url = $this->url;
        $db = $this->db;
        $uid = $request->query('uid') ;
        $odooPassword = $request->header('password');
        $images = $request->input('images');
        $signature = $request->input('signature');
        $transactionId = (int)$request->input('id');
        $dispatchType = $request->input('dispatch_type');
        $requestNumber = $request->input('request_number');
        $actualTime = $request->input('timestamp');
        $enteredName = $request->input('enteredName');
        $newStatus = $request->input('newStatus');
        $containerNumber = $request->input('enteredContainerNumber');

        Log::info('Received file uplodad request', [
            'uid' => $uid,
            'id' => $transactionId,
            'dispatch_type' => $dispatchType,
            'requestNumber' => $requestNumber,
            'actualTime' => $actualTime,
            
            'enteredContainerNumber' => $containerNumber,
            // 'images' => $request->input('images'),
            // 'signature' => $request->input('signature'),
        ]); 

        

        if (!$uid) {
            return response()->json(['success' => false, 'message' => 'UID is required'], 400);
        }

        $odooUrl = $this->odoo_url;
        $proof_attach = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "object",
                "method" => "execute_kw",
                "args" => [
                    $db, 
                    $uid, 
                    $odooPassword, 
                    "dispatch.manager", 
                    "search_read",
                    [[["id", "=", $transactionId]]],  // Search by Request Number
                    ["fields" => ["dispatch_type","de_request_no", "pl_request_no", "dl_request_no", "pe_request_no","service_type", "transport_mode","booking_reference_no" ]]
                ]
            ],
            "id" => 1
        ];
        
        $statusResponse = json_decode(file_get_contents($odooUrl, false, stream_context_create([
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($proof_attach),
            ],
        ])), true);
    
        if (!isset($statusResponse['result']) || empty($statusResponse['result'])) {
            Log::error("❌ No data on this ID", ["response" => $statusResponse]);
            return response()->json(['success' => false, 'message' => 'Data not found'], 404);
        }

        $type = $statusResponse['result'][0] ?? null;
      
        if (!$type) {
            Log::error("❌ Missing dispatch_type", ["response" => $statusResponse]);
            return response()->json(['success' => false, 'message' => 'dispatch_type is missing or invalid'], 404);
        }
        
        // Check that the type is valid before proceeding
        if (!in_array($type['dispatch_type'], ['ot', 'dt'])) {
            Log::error("Incorrect dispatch_type", ["dispatch_type" => $type, "response" => $statusResponse]);
            return response()->json(['success' => false, 'message' => 'Invalid dispatch_type value'], 404);
        }

        return $type;
    }
    private function buildUpdateField1($type, $requestNumber, $images, $signature, $enteredName, $actualTime, $containerNumber, $newStatus, $serviceType) 
    {
        $updateField = [];
        if ($type['dispatch_type'] == "ot" && $type['de_request_no'] == $requestNumber) {
            Log::info("Updating PE proof and signature for request number: {$requestNumber}");
            $pod = isset($images['POD']['content']) && $images['POD']['content'] !== null 
                ? $images['POD']['content'] 
                : null;
            $podFilename = isset($images['POD']['filename']) ? $images['POD']['filename'] : null;
            $updateField = [
                "pe_proof" => $pod,
                "pe_proof_filename" => $podFilename,
                "pe_signature" => $signature,
                "pe_release_by" => $enteredName,
                "stage_id" => 5,
                "de_request_status" => $newStatus,
            ];
            
            
        } elseif ($type['dispatch_type'] == "ot" && $type['pl_request_no'] == $requestNumber) {
            Log::info("Updating PL proof and signature for request number: {$requestNumber}");
            $sales_invoice = isset($images['Sales Invoice']['content']) && $images['Sales Invoice']['content'] !== null 
                ? $images['Sales Invoice']['content'] 
                : null;

            $sales_invoice_filename = isset($images['Sales Invoice']['filename']) ? $images['Sales Invoice']['filename'] : null;

            $stock_transfer = isset($images['Stock Transfer']['content']) && $images['Stock Transfer']['content'] !== null 
                ? $images['Stock Transfer']['content'] 
                : null;

            $stock_transfer_filename = isset($images['Stock Transfer']['filename']) ? $images['Stock Transfer']['filename'] : null;

            $updateField = [
                "pl_proof" => $sales_invoice,
                "pl_signature" => $signature,
                "dl_receive_by" => $enteredName,
                "pl_request_status" => $newStatus,
                "container_number" => $containerNumber,
                "pl_proof_stock" => $stock_transfer,
                "pl_proof_filename_stock" => $stock_transfer_filename,
                "pl_proof_filename" => $sales_invoice_filename
                
            ];
            if($serviceType == 2){
                $updateField["stage_id"] = 5;
            }
            
            
        }

        if ($type['dispatch_type'] == "dt" && $type['dl_request_no'] == $requestNumber) {
            Log::info("Updating PL proof and signature for request number: {$requestNumber}");
            $pod = isset($images['POD']['content']) && $images['POD']['content'] !== null 
                ? $images['POD']['content'] 
                : null;
            $podFilename = isset($images['POD']['filename']) ? $images['POD']['filename'] : null;
            
            $updateField = [
                "pl_proof" => $pod,
                "pl_proof_filename" => $podFilename,
                "pl_signature" => $signature,
                "pe_release_by" => $enteredName,
                "stage_id" => 5,
                "dl_request_status" => $newStatus,
                "container_number" => $containerNumber
            ];
            if($serviceType == 2){
                $updateField["stage_id"] = 5;
            }
            
            
        } elseif ($type['dispatch_type'] == "dt" && $type['pe_request_no'] == $requestNumber) {
            Log::info("Updating PE proof and signature for request number: {$requestNumber}");
            $pod = isset($images['POD']['content']) && $images['POD']['content'] !== null 
                ? $images['POD']['content'] 
                : null;
            $podFilename = isset($images['POD']['filename']) ? $images['POD']['filename'] : null;
            $updateField = [
                "pe_proof" => $pod,
                "pe_proof_filename" => $podFilename,
                "pe_signature" => $signature,
                "dl_receive_by" => $enteredName,
                "pe_request_status" => $newStatus,
            ];
        }
        return $updateField;
    }

    private function buildUpdateField2($type, $requestNumber, $images, $signature, $enteredName, $actualTime, $containerNumber, $newStatus, $serviceType)
    {
        $updateField = [];
        $updateBookingStatus = [];
        if ($type['dispatch_type'] == "ot" && $type['de_request_no'] == $requestNumber) {
            Log::info("Updating DE proof and signature for request number: {$requestNumber}");
            $pod = isset($images['POD']['content']) && $images['POD']['content'] !== null 
                ? $images['POD']['content'] 
                : null;
            $podFilename = isset($images['POD']['filename']) ? $images['POD']['filename'] : null;
            $updateField = [
                "de_proof" => $pod,
                "de_proof_filename" => $podFilename,
                "de_signature" => $signature,
                "de_release_by" => $enteredName,
                "de_completion_time" => $actualTime,
                "de_request_status" => $newStatus,
            ];

            
        }  
        if ($type['dispatch_type'] == "ot" && $type['pl_request_no'] == $requestNumber) {
            Log::info("Updating DL proof and signature for request number: {$requestNumber}");
            $pod = isset($images['POD']['content']) && $images['POD']['content'] !== null 
                ? $images['POD']['content'] 
                : null;
            $podFilename = isset($images['POD']['filename']) ? $images['POD']['filename'] : null;
            $updateField = [
                "dl_proof" => $pod,
                "dl_proof_filename" => $podFilename,
                "dl_signature" => $signature,
                "pl_receive_by" => $enteredName,
                "stage_id" => 7,
                "pl_completion_time" => $actualTime,
                "pl_request_status" => $newStatus,
                "container_number" => $containerNumber,
                
            ];

            $updateBookingStatus = [
                "booking_status" => 3
            ];
        }

        if ($type['dispatch_type'] === "dt" && $type['dl_request_no'] === $requestNumber && isset($type['service_type']) && $type['service_type'] == 2) {
            Log::info("Updating DL proof and signature for request number: {$requestNumber} with service_type = 2");
            $pod = isset($images['POD']['content']) && $images['POD']['content'] !== null 
                ? $images['POD']['content'] 
                : null;
            $podFilename = isset($images['POD']['filename']) ? $images['POD']['filename'] : null;
            $updateField = [
                "dl_proof" => $pod,
                "dl_proof_filename" => $podFilename,
                "dl_signature" => $signature,
                "de_release_by" => $enteredName,
                "dl_completion_time" => $actualTime,
                "stage_id" => 7,
                "dl_request_status" => $newStatus,
                "container_number" => $containerNumber,
                
            ];
            $updateBookingStatus = [
                "booking_status" => 1
            ];

        }   
        if($type['dispatch_type'] === "dt" && $type['dl_request_no'] === $requestNumber) {
            $transfer_of_liability = isset($images['Transfer of Liability Form']['content']) && $images['Transfer of Liability Form']['content'] !== null 
                ? $images['Transfer of Liability Form']['content'] 
                : null;
            
            $transfer_filename = isset($images['Transfer of Liability Form']['filename']) ? $images['Transfer of Liability Form']['filename'] : null;

            $hwb_signed = isset($images['HWB—Signed']['content']) && $images['HWB—Signed']['content'] !== null 
                ? $images['HWB—Signed']['content'] 
                : null;

            $hwb_signed_filename = isset($images['HWB—Signed']['filename']) ? $images['HWB—Signed']['filename'] : null;

            $delivery_receipt = isset($images['Delivery Receipt']['content']) && $images['Delivery Receipt']['content'] !== null 
                ? $images['Delivery Receipt']['content'] 
                : null;

            $delivery_receipt_filename = isset($images['Delivery Receipt']['filename']) ? $images['Delivery Receipt']['filename'] : null;

            $packing_list = isset($images['Packing List']['content']) && $images['Packing List']['content'] !== null 
                ? $images['Packing List']['content'] 
                : null;

            $packing_list_filename = isset($images['Packing List']['filename']) ? $images['Packing List']['filename'] : null;

            $delivery_note = isset($images['Delivery Note']['content']) && $images['Delivery Note']['content'] !== null 
                ? $images['Delivery Note']['content'] 
                : null;

            $delivery_note_filename = isset($images['Delivery Note']['filename']) ? $images['Delivery Note']['filename'] : null;

            $stock_delivery_receipt = isset($images['Stock Delivery Receipt']['content']) && $images['Stock Delivery Receipt']['content'] !== null 
                ? $images['Stock Delivery Receipt']['content'] 
                : null;

            $stock_delivery_receipt_filename = isset($images['Stock Delivery Receipt']['filename']) ? $images['Stock Delivery Receipt']['filename'] : null;

            $sales_invoice = isset($images['Sales Invoice']['content']) && $images['Sales Invoice']['content'] !== null 
                ? $images['Sales Invoice']['content'] 
                : null;

            $sales_invoice_filename = isset($images['Sales Invoice']['filename']) ? $images['Sales Invoice']['filename'] : null;

            $updateField = [
                "dl_proof" => $transfer_of_liability,
                "dl_proof_filename" => $transfer_filename,
                "dl_signature" => $signature,
                "de_release_by" => $enteredName,
                "dl_completion_time" => $actualTime,
                "dl_request_status" => $newStatus,
                "container_number" => $containerNumber,
                "dl_hwb_signed" => $hwb_signed,
                "dl_hwb_signed_filename" => $hwb_signed_filename,
                "dl_delivery_receipt" => $delivery_receipt,
                "dl_delivery_receipt_filename" => $delivery_receipt_filename,
                "dl_packing_list" => $packing_list,
                "dl_packing_list_filename" => $packing_list_filename,
                "dl_delivery_note" => $delivery_note,
                "dl_delivery_note_filename" => $delivery_note_filename,
                "dl_stock_delivery_receipt" => $stock_delivery_receipt,
                "dl_stock_delivery_receipt_filename" => $stock_delivery_receipt_filename,
                "dl_sales_invoice" => $sales_invoice,
                "dl_sales_invoice_filename" => $sales_invoice_filename
            ];
            $updateBookingStatus = [
                "booking_status" => 1
            ];
        }  
        if ($type['dispatch_type'] === "dt" && $type['pe_request_no'] === $requestNumber) {
            Log::info("Updating DE proof and signature for request number: {$requestNumber}");
            $pod = isset($images['POD']['content']) && $images['POD']['content'] !== null 
                ? $images['POD']['content'] 
                : null;
            $podFilename = isset($images['POD']['filename']) ? $images['POD']['filename'] : null;
            $updateField = [
                "de_proof" => $pod,
                "de_proof_filename" => $podFilename,
                "de_signature" => $signature,
                "pl_receive_by" => $enteredName,
                "stage_id" => 7,
                "pe_completion_time" => $actualTime,
                "pe_request_status" => $newStatus,
                "container_number" => $containerNumber
            ];
        }
        return [
            'updateField' => $updateField,
            'updateBookingStatus' => $updateBookingStatus,
        ];
    }


    private function updateFFContainerNumber($type, $containerNumber, $db, $uid, $odooPassword, $odooUrl)
    {
        $bookingRef = $type['booking_reference_no'] ?? null;
        if ($bookingRef && $containerNumber) {
            $searchFF = [
                "jsonrpc" => "2.0",
                "method" => "call",
                "params" => [
                    "service" => "object",
                    "method" => "execute_kw",
                    "args" => [
                        $db,
                        $uid,
                        $odooPassword,
                        "dispatch.manager",
                        "search",
                        [[
                            ["booking_reference_no", '=', $bookingRef],
                            ["dispatch_type", '=', "ff"]
                        ]]
                    ],
                ],
                "id" => 101
            ];
            $ffRes = jsonRpcRequest($odooUrl, $searchFF);
            $ffIds = $ffRes['result'] ?? [];

            if (!empty($ffIds)) {
                // ✅ Update container_number only in ff
                $updateFFContainer = [
                    "jsonrpc" => "2.0",
                    "method" => "call",
                    "params" => [
                        "service" => "object",
                        "method" => "execute_kw",
                        "args" => [
                            $db,
                            $uid,
                            $odooPassword,
                            "dispatch.manager",
                            "write",
                            [
                                $ffIds,
                                [
                                    "container_number" => $containerNumber
                                ]
                            ]
                        ]
                    ],
                    "id" => 102
                ];
                $ffUpdateRes = jsonRpcRequest($odooUrl, $updateFFContainer);
                Log::info("Updated container_number in FF for bookingRef {$bookingRef}, ffIds: " . json_encode($ffIds));
            } else {
                Log::warning("No FF found for bookingRef {$bookingRef}");
            }
        }
    }

    private function updateDispatchRecord($transactionId, $updateField, $db, $uid, $odooPassword, $odooUrl)
    {
        $updatePOD = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "object",
                "method" => "execute_kw",
                "args" => [
                    $db, 
                    $uid, 
                    $odooPassword, 
                    "dispatch.manager", 
                    "write",
                    [
                        [$transactionId],
                       
                        $updateField,
                        
                    ]
                ],
                "kwargs" => [
                    "context" => [
                        "skip_set_status" => true
                    ]
                ]
            ],
            "id" => 4
        ];

        $response = file_get_contents($odooUrl, false, stream_context_create([
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($updatePOD),
            ]
        ]));

        return json_decode($response, true);

    }

    private function getMilestoneHistory($transactionId, $db, $uid, $odooPassword, $odooUrl)
    {
        $milestoneCodeSearch = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "object",
                "method" => "execute_kw",
                "args" => [
                    $db, 
                    $uid, 
                    $odooPassword, 
                    "dispatch.milestone.history", 
                    "search_read",
                    [[["dispatch_id", "=", $transactionId]]],  // Search by Request Number
                    ["fields" => ["id","dispatch_type","actual_datetime","scheduled_datetime","fcl_code","is_backload"]]
                ]
            ],
            "id" => rand(1000,9999)
        ];

         Log::debug("🔍 Milestone History Search Payload", $milestoneCodeSearch);
    
        $response = file_get_contents($odooUrl, false, stream_context_create([
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($milestoneCodeSearch),
            ],
        ]));

        $fcl_code_response = json_decode($response, true);

        if (!isset($fcl_code_response['result']) || empty($fcl_code_response['result'])) {
            Log::error("❌ No data on this ID (milestone level)", ["response" => $fcl_code_response]);
            return response()->json(['success' => false, 'message' => 'Data not found'], 404);
        }

        return $fcl_code_response['result'];
    }

    private function updateMilestoneAndSendEmail(array $milestoneResultList, string $milestoneCodeToUpdate, string $actualTime, string $db, int $uid, string $odooPassword, string $odooUrl)
    {
        $milestoneIdToUpdate = null;
        $fcl_code = null;

        foreach ($milestoneResultList as $milestone) {
            if ($milestone['fcl_code'] === $milestoneCodeToUpdate) {
                $milestoneIdToUpdate = $milestone['id'];
                $fcl_code = $milestone['fcl_code'];
                    Log::info("🆗 Milestone matched and ID found", [
                    'milestone_id' => $milestoneIdToUpdate,
                    'fcl_code' => $fcl_code
                ]);
                break;
            }
        }

        if (!$milestoneIdToUpdate) {
            return response()->json(['success' => false, 'message' => 'Milestone not found'], 404);
        }

        $update_actual_time = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "object",
                "method" => "execute_kw",
                "args" => [
                    $db,
                    $uid,
                    $odooPassword,
                    "dispatch.milestone.history",
                    "write",
                    [
                        [$milestoneIdToUpdate],
                        [
                            'actual_datetime' => $actualTime,
                            'button_readonly' => true, 
                            'button_confirm_semd' => false,
                            'clicked_by' => (int) $uid,
                        ]
                    ]
                ]
            ],
            "id" => 6
        ];

        $updateActualResponse = json_decode(file_get_contents($odooUrl, false, stream_context_create([
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($update_actual_time),
            ]
        ])), true);
        Log::debug("📝 Actual time update response", ['response' => $updateActualResponse]);

        if (!isset($updateActualResponse['result']) || !$updateActualResponse['result']) {
            Log::error("⚠️ POD updated but failed to update milestone", ['response' => $updateActualResponse]);
            return response()->json(['success' => false, 'message' => 'POD updated but milestone failed'], 500);
        }
                   
        $fcl_code_email = [
            'TYOT' => 'dispatch_manager.a2_email_notification_shipper_template',
            'TEOT' => 'dispatch_manager.a7_shipper_arrived_shiplocation_template',
            'TLOT' => 'dispatch_manager.a5_email_notification_laden_template',
            'CLOT' => 'dispatch_manager.a6_notification_container_outbound_template',
            'CYDT' => 'dispatch_manager.b4_container_vendor_yard_template',
            'GLDT' => 'dispatch_manager.a5_email_notification_laden_template',
            'CLDT' => 'dispatch_manager.c2_consignee_arrived_conslocation_template',
            'GYDT' => 'dispatch_manager.a2_email_notification_shipper_template',
            'ELOT' => 'dispatch_manager.a5_email_notification_laden_template',
            'EEDT' => 'dispatch_manager.a5_email_notification_laden_template',
            'LTEOT' => 'dispatch_manager.d1_email_notif_item_template',
            'LCLOT' => 'dispatch_manager.d2_item_sorting_hub_template',
            'LGYDT' => 'dispatch_manager.f2_consignee_driver_deliver_template',
            'LCLDT' => 'dispatch_manager.f3_shipper_consignee_complete_template',
            'TTEOT' => 'dispatch_manager.g2_truck_driver_cargo_shipper_template',
            'TCLOT' => 'dispatch_manager.g3_email_arrived_consignee_template',
        ];

        $template_xml_id = $fcl_code_email[$fcl_code] ?? null;

        if($template_xml_id) {
            Log::info("✅ Actual datetime successfully updated for milestone ID: $milestoneIdToUpdate");
            [$module, $xml_id] = explode('.', $template_xml_id, 2);
            $get_template_id = [
                "jsonrpc" => "2.0",
                "method" => "call",
                "params" => [
                    "service" => "object",
                    "method" => "execute_kw",
                    "args" => [
                        $db,
                        $uid,
                        $odooPassword,
                        "ir.model.data",
                        "search_read",
                        [
                            [["module", "=", $module], ["name", "=", $xml_id]],
                            ["res_id"]
                        ]
                        
                    ]
                ],
                "id" => 7
            ];
            $templateResponse = json_decode(file_get_contents($odooUrl, false, stream_context_create([
                "http" => [
                    "header" => "Content-Type: application/json",
                    "method" => "POST",
                    "content" => json_encode($get_template_id),
                ]
            ])), true);

            Log::debug("🔍 Template response", ['response' => $templateResponse]);

            $template_id = $templateResponse['result'] ?? [];

            if (!empty($template_id) && isset($template_id[0]['res_id'])) {
                $resolved_id = $template_id[0]['res_id'];
                Log::info("📩 Template ID resolved: $resolved_id for $template_xml_id");

                $send_email = [
                    "jsonrpc" => "2.0",
                    "method" => "call",
                    "params" => [
                        "service" => "object",
                        "method" => "execute_kw",
                        "args" => [
                            $db,
                            $uid,
                            $odooPassword,
                            "mail.template",
                            "send_mail",
                            [
                                $resolved_id,
                                $milestoneIdToUpdate,
                                true
                            ]
                        ]
                    ],
                    "id" => 8
                ];

                $sendEmailResponse = json_decode(file_get_contents($odooUrl, false, stream_context_create([
                    "http" => [
                        "header" => "Content-Type: application/json",
                        "method" => "POST",
                        "content" => json_encode($send_email),
                    ]
                ])), true);

                if(isset($sendEmailResponse['result']) && $sendEmailResponse['result']) {
                    Log::info("Milestone updated and email sent.");
                    return response()->json([
                        'success' => true,
                        'message' => 'Milestone updated and email sent successfully.',
                        'milestone_id' => $milestoneIdToUpdate,
                        'template_id' =>  $resolved_id,

                    ], 200);
                } else {
                    Log::warning("Milestone update, but email is not sent", ['response' => $sendEmailResponse]);
                    return response()->json(['success' => true, 'message' => 'Milestsone updated, but email failed'], 200);
                }
            } else {
                Log::error("Failed to resolve template XML ID $template_xml_id");
                return response()->json(['success' => false, 'message' => 'Template not found'], 500);
            }
            Log::info("Milestone updated!");
        } else {
            Log::warning("No template configured for FCL Code: $fcl_code");
            return response()->json(['success' => true, 'message' => 'Milestone updated but no email sent'], 200);
        }
    }

    
    private function resolveMilestoneCode($type, $requestNumber, $serviceType)
    {
        $transportMode = is_array($type['transport_mode']) ? $type['transport_mode'][0] : $type['transport_mode'];
        if ($type['dispatch_type'] == "ot" && $type['pl_request_no'] == $requestNumber && $transportMode == 1) {
            return "TTEOT";
        }
        if ($type['dispatch_type'] == "ot" && $type['de_request_no'] == $requestNumber && $serviceType == 1) {
            return "TYOT";
        }
        if ($type['dispatch_type'] == "ot" && $type['pl_request_no'] == $requestNumber && $serviceType == 1) {
            return "TLOT";
        }
        if ($type['dispatch_type'] == "dt" && $type['dl_request_no'] == $requestNumber && $serviceType == 1) {
            return "GYDT";
        }
        if ($type['dispatch_type'] == "dt" && $type['pe_request_no'] == $requestNumber && $serviceType == 1) {
            return "GLDT";
        }
        if ($type['dispatch_type'] == "ot" && $type['pl_request_no'] == $requestNumber && $serviceType == 2) {
            return "LTEOT";
        }
        if ($type['dispatch_type'] == "dt" && $type['dl_request_no'] == $requestNumber && $serviceType == 2) {
            return "LGYDT";
        }
        
        return null;
    }

    private function resolveMilestoneCode2($type, $requestNumber, $serviceType)
    {
        $transportMode = is_array($type['transport_mode']) ? $type['transport_mode'][0] : $type['transport_mode'];
        if ($type['dispatch_type'] == "ot" && $type['pl_request_no'] == $requestNumber && $transportMode == 1) {
             Log::info("🚚 Entered TCLOT branch for land transport");
            return "TCLOT";
        }
        if ($type['dispatch_type'] == "ot" && $type['de_request_no'] == $requestNumber && $serviceType == 1) {
            return "TEOT";
        }
        if ($type['dispatch_type'] == "ot" && $type['pl_request_no'] == $requestNumber && $serviceType == 1 ) {
            return "CLOT";
        }
        if ($type['dispatch_type'] == "dt" && $type['dl_request_no'] == $requestNumber && $serviceType == 1) {
            return "CLDT";
        }
        if ($type['dispatch_type'] == "dt" && $type['pe_request_no'] == $requestNumber && $serviceType == 1) {
            return "CYDT";
        }
        if ($type['dispatch_type'] == "ot" && $type['pl_request_no'] == $requestNumber && $serviceType == 2) {
            return "LCLOT";
        }
        if ($type['dispatch_type'] == "dt" && $type['dl_request_no'] == $requestNumber && $serviceType == 2) {
            return "LCLDT";
        }
       
        return null;
    }

    private function resolveMilestoneCode3($type, $requestNumber, $serviceType)
    {
       
        if ($type['dispatch_type'] == "ot" && $type['pl_request_no'] == $requestNumber && $serviceType == 1) {
            return "ELOT";
        }
       
        if ($type['dispatch_type'] == "dt" && $type['pe_request_no'] == $requestNumber && $serviceType == 1) {
            return "EEDT";
        }
  
        return null;
    }

   
    private function consolidationMaster($transactionId,$actualTime,$db,$uid,$odooPassword,$odooUrl,$bookingRef)
    {
        $notebookRes = jsonRpcRequest($odooUrl, [
            'jsonrpc' => '2.0',
            'method' => 'call',
            'params' => [
                'service' => 'object',
                'method' => 'execute_kw',
                'args' => [$db, $uid, $odooPassword, 'consol.type.notebook', 'search_read',
                    [[['consol_destination', '=', $transactionId]]],
                    [
                        'fields' => ['id', 'consolidation_id', 'consol_origin','consol_destination','type_consol'],
                        'order' => 'id desc',  // <--- get latest row first
                        'limit' => 1           // <--- only fetch the latest row
                    ]
                ]
            ],
            'id' => rand(1000, 9999)
        ]);

        
        if (empty($notebookRes['result'])) {
            return; // no consolidation notebook found
        }
       
         $resultSummary = [];

        foreach ($notebookRes['result'] as $nb) {
            $consolMasterId = $nb['consolidation_id'][0] ?? null;
            $consolOriginId = $nb['consol_origin'][0] ?? null;
            $consolDestinationId = $nb['consol_destination'][0] ?? null;
            $consolType = $nb['type_consol'][0] ?? null;

            if(!$consolMasterId) continue;

            $masterRes = jsonRpcRequest($odooUrl, [
                'jsonrpc' => '2.0',
                'method' => 'call',
                'params' => [
                    'service' => 'object',
                    'method' => 'execute_kw',
                    'args' => [
                        $db,
                        $uid,
                        $odooPassword,
                        'pd.consol.master',
                        'search_read',
                        [[['id', '=', $consolMasterId]]],
                        ['fields' => ['id', 'status']]
                    ]
                ],
                'id' => rand(1000, 9999)
            ]);

            $master = $masterRes['result'][0] ?? null;
            $status = strtolower($master['status'] ?? '');

            if (in_array($status, ['draft', 'cancelled']) && $consolType !== 1) {
                Log::info('⏩ Skipping backload — status not consolidated', [
                    'consolMasterId' => $consolMasterId,
                    'status' => $status
                ]);
                continue; // Stop execution entirely
            }

            Log::info('⏩ Processing backloaded notebook', [
                'consolMasterId' => $consolMasterId,
                'coonsolDestinationId' => $consolDestinationId
            ]);

            if ($consolDestinationId && $consolType == 1) {
                $updateDestinationStage = jsonRpcRequest($odooUrl, [
                    'jsonrpc' => '2.0',
                    'method' => 'call',
                    'params' => [
                        'service' => 'object',
                        'method' => 'execute_kw',
                        'args' => [
                            $db, $uid, $odooPassword,
                            'dispatch.manager', 'write',
                            [[$consolDestinationId], ['stage_id' => 7, 'de_completion_time' => $actualTime]]
                        ]
                    ],
                    'id' => rand(1000, 9999)
                ]);

                Log::info("Backloaded destination forced to stage 7", [
                    'consolDestinationId' => $consolDestinationId,
                    'response' => $updateDestinationStage
                ]);

                $updateConsolMaster = jsonRpcRequest($odooUrl, [
                    'jsonrpc' => '2.0',
                    'method' => 'call',
                    'params' => [
                        'service' => 'object',
                        'method' => 'execute_kw',
                        'args' => [$db, $uid, $odooPassword, 'pd.consol.master', 'write',
                            [[$consolMasterId], ['status' => 'execution']]
                        ]
                    ],
                    'id' => rand(1000, 9999)
                ]);

                Log::info("Consolidation master updated", ['consolMasterId' => $consolMasterId, 'response' => $updateConsolMaster]);
                $resultSummary['updateConsolMaster'] = $updateConsolMaster;

                if($consolOriginId) {
                    $updateConsolOrigin = jsonRpcRequest($odooUrl, [
                        'jsonrpc' => '2.0',
                        'method' => 'call',
                        'params' => [
                            'service' => 'object',
                            'method' => 'execute_kw',
                            'args' => [$db, $uid, $odooPassword, 'dispatch.manager', 'write',
                                [[$consolOriginId], ['stage_id' => 5]]
                            ]
                        ],
                        'id' => rand(1000, 9999)
                    ]);
                    Log::info("Consolidation origin updated", ['consolOriginId' => $consolOriginId, 'response' => $updateConsolOrigin]);
                    $resultSummary['updateConsolOrigin'] = $updateConsolOrigin;

                    $searchBooking = jsonRpcRequest($odooUrl,[
                        "jsonrpc" => "2.0",
                        "method" => "call",
                        "params" => [
                            "service" => "object",
                            "method" => "execute_kw",
                            "args" => [
                                $db,
                                $uid,
                                $odooPassword,
                                "freight.management",
                                "search_read",
                                [[["booking_reference_no", '=', $bookingRef]]],
                                ["fields" => ["id", "stage_id"]]
                            ],
                        ],
                        "id" => rand(1000, 9999)
                    ]);
                
                    
                    $bookingIds = $searchBooking['result'][0]['id'] ?? null;

                    if ($bookingIds) {
                        $updateBookingStage =jsonRpcRequest($odooUrl, [
                            "jsonrpc" => "2.0",
                            "method" => "call",
                            "params" => [
                                "service" => "object",
                                "method" => "execute_kw",
                                "args" => [
                                    $db,
                                    $uid,
                                    $odooPassword,
                                    "freight.management",
                                    "write",
                                    [
                                        [$bookingIds],
                                        [
                                            "stage_id" => 6
                                        ]
                                    ]
                                ]
                            ],
                            "id" => rand(1000, 9999)
                        ]);
                        $resultSummary['updateBookingStage'] = $updateBookingStage;
                        Log::info("Updated booking stage for bookingRef {$bookingRef}, bookingId: {$bookingIds}");
                    
                    } else {
                        Log::warning("No booking found for bookingRef {$bookingRef}");
                    }

                    $fclToUpdate = ['TYOT', 'TEOT'];

                    $milestones = jsonRpcRequest($odooUrl, [
                        'jsonrpc' => '2.0',
                        'method' => 'call',
                        'params' => [
                            'service' => 'object',
                            'method' => 'execute_kw',
                            'args' => [$db, $uid, $odooPassword, 'dispatch.milestone.history', 'search_read',
                                [[['dispatch_id', '=', $consolOriginId], ['fcl_code', 'in', $fclToUpdate]]],
                                ['fields' => ['id','fcl_code']]
                            ]
                        ],
                        'id' => rand(1000, 9999)
                    ]);
                    foreach ($milestones['result'] as $ms) {
                        $updateMilestone = jsonRpcRequest($odooUrl, [
                            'jsonrpc' => '2.0',
                            'method' => 'call',
                            'params' => [
                                'service' => 'object',
                                'method' => 'execute_kw',
                                'args' => [$db, $uid, $odooPassword, 'dispatch.milestone.history', 'write',
                                    [[$ms['id']], [
                                    'actual_datetime' => $actualTime,
                                    'button_readonly' => true,
                                    'button_confirm_semd' => false,
                                    'clicked_by' => (int) $uid,
                                    'milestone_status' => 'Backload'
                                ]]
                                ]
                            ],
                            'id' => rand(1000, 9999)
                        ]);
                        Log::info("Consolidation origin milestone updated", ['consolOriginId' => $consolOriginId, 'milestoneId' => $ms['id'], 'fcl_code' => $fclToUpdate, 'response' => $updateMilestone]);
                        $resultSummary['milestone'][] = $updateMilestone;
                    }
                }      // Continue with normal master/origin updates even if destination updated
            }
        }

        return $resultSummary;
    }

  
    private function divertedConsol($transactionId, $actualTime, $db, $uid, $odooPassword, $odooUrl, $bookingRef)
    {
        $notebookRes = jsonRpcRequest($odooUrl, [
            'jsonrpc' => '2.0',
            'method'  => 'call',
            'params'  => [
                'service' => 'object',
                'method'  => 'execute_kw',
                'args'    => [
                    $db, $uid, $odooPassword,
                    'consol.type.notebook', 'search_read',
                    [[['consol_destination', '=', $transactionId]]],
                    [
                        'fields' => ['id', 'consolidation_id', 'consol_origin','consol_destination','type_consol'],
                        'order' => 'id desc',  // <--- get latest row first
                        'limit' => 1           // <--- only fetch the latest row
                    ]
                ]
            ],
            'id' => rand(1000, 9999)
        ]);

        if (empty($notebookRes['result'])) {
            Log::info("divertedConsol: no notebook rows for transaction", ['transactionId' => $transactionId]);
            return [];
        }

        $resultSummary = [];

        foreach ($notebookRes['result'] as $nb) {
            // normalize fields
            $consolMasterId = $nb['consolidation_id'][0] ?? null;
            $consolOriginId = $nb['consol_origin'][0] ?? null;
            $consolDestinationId = $nb['consol_destination'][0] ?? null;

            // type_consol may be an array [id, "Label"] or scalar
            $typeConsolRaw = $nb['type_consol'] ?? null;
            $consolType = null;
            if (is_array($typeConsolRaw)) {
                $consolType = (int)($typeConsolRaw[0] ?? 0);
            } else {
                $consolType = (int)$typeConsolRaw;
            }

            if (!$consolMasterId) {
                Log::warning("divertedConsol: notebook row missing consolidation_id, skipping", ['notebook' => $nb]);
                continue;
            }

            // fetch master and ensure consolidated
            $masterRes = jsonRpcRequest($odooUrl, [
                'jsonrpc' => '2.0',
                'method'  => 'call',
                'params'  => [
                    'service' => 'object',
                    'method'  => 'execute_kw',
                    'args'    => [
                        $db, $uid, $odooPassword,
                        'pd.consol.master', 'search_read',
                        [[['id', '=', $consolMasterId]]],
                        ['fields' => ['id', 'status']]
                    ]
                ],
                'id' => rand(1000, 9999)
            ]);

            $master = $masterRes['result'][0] ?? null;
            $status = strtolower($master['status'] ?? '');

            if (in_array($status, ['draft', 'cancelled']) && $consolType !== 2) {
                Log::info("divertedConsol: consol master not consolidated, skipping this notebook row", [
                    'consolMasterId' => $consolMasterId,
                    'status' => $status
                ]);
                continue;
            }

            Log::info("divertedConsol: processing consolidated notebook", [
                'consolMasterId' => $consolMasterId,
                'consolOriginId' => $consolOriginId,
                'consolDestinationId' => $consolDestinationId,
                'consolType' => $consolType
            ]);

            // If type is diverted/backload (your code used 2 for Diverted), handle destination GLDT
            if ($consolDestinationId && $consolType === 2) {
                // Update destination GLDT milestone only
                $destMilestones = jsonRpcRequest($odooUrl, [
                    'jsonrpc' => '2.0',
                    'method'  => 'call',
                    'params'  => [
                        'service' => 'object',
                        'method'  => 'execute_kw',
                        'args'    => [
                            $db, $uid, $odooPassword,
                            'dispatch.milestone.history', 'search_read',
                            [[['dispatch_id', '=', $consolDestinationId], ['fcl_code', '=', 'GLDT']]],
                            ['fields' => ['id', 'fcl_code']]
                        ]
                    ],
                    'id' => rand(1000, 9999)
                ]);
                $updateOrigin = jsonRpcRequest($odooUrl, [
                    'jsonrpc' => '2.0',
                    'method' => 'call',
                    'params' => [
                        'service' => 'object',
                        'method' => 'execute_kw',
                        'args' => [$db, $uid, $odooPassword, 'dispatch.manager', 'write',
                            [[$consolOriginId], ['de_request_status' => 'Ongoing']] 
                        ]
                    ],
                    'id' => rand(1000, 9999)
                ]);
                Log::info("🔄 Consol origin set to ongoing due to GLDT milestone", [
                    'consolOriginId' => $consolOriginId,
                    'response' => $updateOrigin
                ]);

                if (!empty($destMilestones['result'])) {
                    foreach ($destMilestones['result'] as $ms) {
                        $msId = $ms['id'] ?? null;
                        if (!$msId) continue;

                        $updateMilestone = jsonRpcRequest($odooUrl, [
                            'jsonrpc' => '2.0',
                            'method'  => 'call',
                            'params'  => [
                                'service' => 'object',
                                'method'  => 'execute_kw',
                                'args'    => [
                                    $db, $uid, $odooPassword,
                                    'dispatch.milestone.history', 'write',
                                    [[$msId], [
                                        'actual_datetime' => $actualTime,
                                        'button_readonly' => true,
                                        'button_confirm_semd' => false,
                                        'clicked_by' => (int)$uid,
                                        'milestone_status' => 'Diverted'
                                    ]]
                                ]
                            ],
                            'id' => rand(1000, 9999)
                        ]);

                        $resultSummary['destination_milestone_updates'][] = $updateMilestone;
                        Log::info("Destination GLDT milestone updated", ['consolDestinationId' => $consolDestinationId, 'milestoneId' => $msId, 'response' => $updateMilestone]);

                        // set destination dispatch to stage 7 (PE completed) and mark completion time
                        $updateDestDispatch = jsonRpcRequest($odooUrl, [
                            'jsonrpc' => '2.0',
                            'method'  => 'call',
                            'params'  => [
                                'service' => 'object',
                                'method'  => 'execute_kw',
                                'args'    => [
                                    $db, $uid, $odooPassword,
                                    'dispatch.manager', 'write',
                                    [[$consolDestinationId], ['stage_id' => 7, 'pe_completion_time' => $actualTime, 'pe_request_status' => 'Completed']]
                                ]
                            ],
                            'id' => rand(1000, 9999)
                        ]);
                        $resultSummary['destination_dispatch_update'] = $updateDestDispatch;
                        Log::info("Destination dispatch moved to stage 7", ['consolDestinationId' => $consolDestinationId, 'response' => $updateDestDispatch]);

                        // update freight.management for the destination booking (if booking found by booking_ref)
                        if (!empty($bookingRef)) {
                            $searchDestinationBooking = jsonRpcRequest($odooUrl, [
                                "jsonrpc" => "2.0",
                                "method"  => "call",
                                "params"  => [
                                    "service" => "object",
                                    "method"  => "execute_kw",
                                    "args"    => [
                                        $db, $uid, $odooPassword,
                                        "freight.management", "search_read",
                                        [[["booking_reference_no", '=', $bookingRef]]],
                                        ["fields" => ["id", "stage_id"]]
                                    ],
                                ],
                                "id" => rand(1000, 9999)
                            ]);

                            $desBookingId = $searchDestinationBooking['result'][0]['id'] ?? null;
                            if ($desBookingId) {
                                $updateDesBookingStage = jsonRpcRequest($odooUrl, [
                                    "jsonrpc" => "2.0",
                                    "method"  => "call",
                                    "params"  => [
                                        "service" => "object",
                                        "method"  => "execute_kw",
                                        "args"    => [
                                            $db, $uid, $odooPassword,
                                            "freight.management", "write",
                                            [[$desBookingId], ["stage_id" => 6]]
                                        ]
                                    ],
                                    "id" => rand(1000, 9999)
                                ]);
                                $resultSummary['destination_booking_update'] = $updateDesBookingStage;
                                Log::info("Destination freight.management updated to stage 6", ['bookingRef' => $bookingRef, 'bookingId' => $desBookingId, 'response' => $updateDesBookingStage]);
                            } else {
                                Log::warning("divertedConsol: no freight.management booking found for destination bookingRef", ['bookingRef' => $bookingRef]);
                            }
                        }
                    } // foreach dest milestones
                } else {
                    Log::info("divertedConsol: no GLDT milestone found for destination", ['consolDestinationId' => $consolDestinationId]);
                }

                // Set consol master status to 'execution' (safe single call)
                $updateConsolMaster = jsonRpcRequest($odooUrl, [
                    'jsonrpc' => '2.0',
                    'method'  => 'call',
                    'params'  => [
                        'service' => 'object',
                        'method'  => 'execute_kw',
                        'args'    => [
                            $db, $uid, $odooPassword,
                            'pd.consol.master', 'write',
                            [[$consolMasterId], ['status' => 'execution']]
                        ]
                    ],
                    'id' => rand(1000, 9999)
                ]);
                $resultSummary['consol_master_execution'] = $updateConsolMaster;
                Log::info("Consol master set to execution", ['consolMasterId' => $consolMasterId, 'response' => $updateConsolMaster]);
            } // end destination handling

            // Handle origin TYOT updates and origin stage/booking updates (only if origin exists)
            if ($consolOriginId) {
                // TYOT milestone on origin - only update TYOT (if present)
                $originTyotSearch = jsonRpcRequest($odooUrl, [
                    'jsonrpc' => '2.0',
                    'method'  => 'call',
                    'params'  => [
                        'service' => 'object',
                        'method'  => 'execute_kw',
                        'args'    => [
                            $db, $uid, $odooPassword,
                            'dispatch.milestone.history', 'search_read',
                            [[['dispatch_id', '=', $consolOriginId], ['fcl_code', '=', 'TYOT']]],
                            ['fields' => ['id', 'fcl_code']]
                        ]
                    ],
                    'id' => rand(1000, 9999)
                ]);

                if (!empty($originTyotSearch['result'])) {
                    foreach ($originTyotSearch['result'] as $tyot) {
                        $tid = $tyot['id'] ?? null;
                        if (!$tid) continue;

                        $updateTyot = jsonRpcRequest($odooUrl, [
                            'jsonrpc' => '2.0',
                            'method'  => 'call',
                            'params'  => [
                                'service' => 'object',
                                'method'  => 'execute_kw',
                                'args'    => [
                                    $db, $uid, $odooPassword,
                                    'dispatch.milestone.history', 'write',
                                    [[$tid], [
                                        'actual_datetime' => $actualTime,
                                        'button_readonly' => true,
                                        'button_confirm_semd' => false,
                                        'clicked_by' => (int)$uid,
                                        'milestone_status' => 'Diverted'
                                    ]]
                                ]
                            ],
                            'id' => rand(1000, 9999)
                        ]);

                        $resultSummary['origin_tyot_updates'][] = $updateTyot;
                        Log::info("Origin TYOT milestone updated", ['consolOriginId' => $consolOriginId, 'milestoneId' => $tid, 'response' => $updateTyot]);
                    }

                    // Move origin dispatch to stage 5 (execution)
                    $updateOriginDispatch = jsonRpcRequest($odooUrl, [
                        'jsonrpc' => '2.0',
                        'method'  => 'call',
                        'params'  => [
                            'service' => 'object',
                            'method'  => 'execute_kw',
                            'args'    => [
                                $db, $uid, $odooPassword,
                                'dispatch.manager', 'write',
                                [[$consolOriginId], ['stage_id' => 5]]
                            ]
                        ],
                        'id' => rand(1000, 9999)
                    ]);
                    $resultSummary['origin_dispatch_update'] = $updateOriginDispatch;
                    Log::info("Origin dispatch moved to stage 5", ['consolOriginId' => $consolOriginId, 'response' => $updateOriginDispatch]);

                    // Get origin booking_reference_no from the origin dispatch and update freight.management (stage 5)
                    $originDispatch = jsonRpcRequest($odooUrl, [
                        "jsonrpc" => "2.0",
                        "method"  => "call",
                        "params"  => [
                            "service" => "object",
                            "method"  => "execute_kw",
                            "args"    => [
                                $db, $uid, $odooPassword,
                                "dispatch.manager", "search_read",
                                [[["id", "=", $consolOriginId]]],
                                ["fields" => ["booking_reference_no"]]
                            ]
                        ],
                        "id" => rand(1000, 9999)
                    ]);
                    $originBookingRef = $originDispatch['result'][0]['booking_reference_no'] ?? null;
                    if ($originBookingRef) {
                        $searchBooking = jsonRpcRequest($odooUrl, [
                            "jsonrpc" => "2.0",
                            "method"  => "call",
                            "params"  => [
                                "service" => "object",
                                "method"  => "execute_kw",
                                "args"    => [
                                    $db, $uid, $odooPassword,
                                    "freight.management", "search_read",
                                    [[["booking_reference_no", "=", $originBookingRef]]],
                                    ["fields" => ["id", "stage_id","container_number"]]
                                ],
                            ],
                            "id" => rand(1000, 9999)
                        ]);

                        $bookingIds = $searchBooking['result'][0]['id'] ?? null;
                        $containerNo =  trim($searchBooking['result'][0]['container_number'] ?? '');
                        if (!empty($containerNo)) {
                            if ($bookingIds) {
                                $updateBookingStage = jsonRpcRequest($odooUrl, [
                                    "jsonrpc" => "2.0",
                                    "method"  => "call",
                                    "params"  => [
                                        "service" => "object",
                                        "method"  => "execute_kw",
                                        "args"    => [
                                            $db, $uid, $odooPassword,
                                            "freight.management", "write",
                                            [[$bookingIds], ["stage_id" => 5]]
                                        ]
                                    ],
                                    "id" => rand(1000, 9999)
                                ]);
                                $resultSummary['origin_booking_update'] = $updateBookingStage;
                                Log::info("Origin freight.management updated to stage 5", ['originBookingRef' => $originBookingRef, 'bookingId' => $bookingIds, 'response' => $updateBookingStage]);
                            } else {
                                Log::warning("divertedConsol: no freight.management booking found for origin bookingRef", ['originBookingRef' => $originBookingRef]);
                            }
                        } else {
                            Log::warning("divertedConsol: origin dispatch has no container number", ['consolOriginId' => $consolOriginId]);
                        }
                    } else {
                        Log::warning("divertedConsol: origin dispatch has no booking_reference_no", ['consolOriginId' => $consolOriginId]);
                    }
                } else {
                    Log::info("divertedConsol: no TYOT milestone found for origin", ['consolOriginId' => $consolOriginId]);
                }
            } // end origin handling
        } // end foreach notebook rows

        return $resultSummary;
    }
   

    private function updateBookingStage1($bookingRef, $db, $uid, $odooPassword, $odooUrl)
    {
        if (!$bookingRef) return;

        $searchBooking = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "object",
                "method" => "execute_kw",
                "args" => [
                    $db,
                    $uid,
                    $odooPassword,
                    "freight.management",
                    "search_read",
                    [[["booking_reference_no", '=', $bookingRef]]],
                    ["fields" => ["id", "stage_id", "waybill_id"]]
                ],
            ],
            "id" => rand(1000, 9999)
        ];
        $searchResponse = json_decode(file_get_contents($odooUrl, false, stream_context_create([
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($searchBooking),
            ]
        ])), true);
        
        $bookingIds = $searchResponse['result'][0]['id'] ?? null;
        $waybillId = $searchResponse['result'][0]['waybill_id'] ?? null;

        if ($bookingIds) {
            if ($waybillId) {
                $updateBookingStage = [
                    "jsonrpc" => "2.0",
                    "method" => "call",
                    "params" => [
                        "service" => "object",
                        "method" => "execute_kw",
                        "args" => [
                            $db,
                            $uid,
                            $odooPassword,
                            "freight.management",
                            "write",
                            [
                                [$bookingIds],
                                [
                                    "stage_id" => 5
                                ]
                            ]
                        ]
                    ],
                    "id" => rand(1000, 9999)
                ];
                $response = json_decode(file_get_contents($odooUrl, false, stream_context_create([
                    "http" => [
                        "header" => "Content-Type: application/json",
                        "method" => "POST",
                        "content" => json_encode($updateBookingStage),
                    ]
                ])), true);

                Log::info("Updated booking stage for bookingRef {$bookingRef}, bookingId: {$bookingIds}");

                return $response;
            } else {
                Log::warning("No found for {$bookingRef} but no waybill");
            }
            
        } else {
            Log::warning("No booking found for bookingRef {$bookingRef}");
        }
    }

    private function updateBookingStage2($bookingRef, $db, $uid, $odooPassword, $odooUrl)
    {
        if (!$bookingRef) return;

        $searchBooking = [
            "jsonrpc" => "2.0",
            "method" => "call",
            "params" => [
                "service" => "object",
                "method" => "execute_kw",
                "args" => [
                    $db,
                    $uid,
                    $odooPassword,
                    "freight.management",
                    "search_read",
                    [[["booking_reference_no", '=', $bookingRef]]],
                    ["fields" => ["id", "stage_id"]]
                ],
            ],
            "id" => rand(1000, 9999)
        ];
        $searchResponse = json_decode(file_get_contents($odooUrl, false, stream_context_create([
            "http" => [
                "header" => "Content-Type: application/json",
                "method" => "POST",
                "content" => json_encode($searchBooking),
            ]
        ])), true);
        
        $bookingIds = $searchResponse['result'][0]['id'] ?? null;

        if ($bookingIds) {
            $updateBookingStage = [
                "jsonrpc" => "2.0",
                "method" => "call",
                "params" => [
                    "service" => "object",
                    "method" => "execute_kw",
                    "args" => [
                        $db,
                        $uid,
                        $odooPassword,
                        "freight.management",
                        "write",
                        [
                            [$bookingIds],
                            [
                                "stage_id" => 6
                            ]
                        ]
                    ]
                ],
                "id" => rand(1000, 9999)
            ];
            $response = json_decode(file_get_contents($odooUrl, false, stream_context_create([
                "http" => [
                    "header" => "Content-Type: application/json",
                    "method" => "POST",
                    "content" => json_encode($updateBookingStage),
                ]
            ])), true);

            Log::info("Updated booking stage for bookingRef {$bookingRef}, bookingId: {$bookingIds}");

            return $response;
           
        } else {
            Log::warning("No booking found for bookingRef {$bookingRef}");
        }
    }

    private function updateBookingStatus($bookingRef, $db, $uid, $odooPassword, $odooUrl, $updateBookingStatus, $transactionId = null)
    {
        if (!$bookingRef) return;

        // 1️⃣ First, normal booking lookup
        $searchResponse = jsonRpcRequest($odooUrl, [
            'jsonrpc' => '2.0',
            'method' => 'call',
            'params' => [
                'service' => 'object',
                'method' => 'execute_kw',
                'args' => [
                    $db,
                    $uid,
                    $odooPassword,
                    'freight.management',
                    'search_read',
                    [[['booking_reference_no', '=', $bookingRef]]],
                    ['fields' => ['id', 'stage_id']]
                ]
            ],
            'id' => rand(1000, 9999)
        ]);

        $bookingId = $searchResponse['result'][0]['id'] ?? null;

        if (!$bookingId) {
            Log::warning("No booking found for bookingRef {$bookingRef}");
            return;
        }

        // 2️⃣ Check if this booking is part of a consolidated destination
        $notebookRes = jsonRpcRequest($odooUrl, [
            'jsonrpc' => '2.0',
            'method' => 'call',
            'params' => [
                'service' => 'object',
                'method' => 'execute_kw',
                'args' => [
                    $db, $uid, $odooPassword,
                    'consol.type.notebook', 'search_read',
                    [[['consol_destination', '=', $transactionId]]],
                    ['fields' => ['id', 'type_consol', 'consol_destination']]
                ]
            ],
            'id' => rand(1000, 9999)
        ]);

        $consolNotebook = $notebookRes['result'][0] ?? null;
        $consolType = $consolNotebook['type_consol'][0] ?? null;

        // 3️⃣ Decide if we should force stage 6
        if ($consolNotebook && $consolType == 1) {
            Log::info("BookingRef {$bookingRef} is part of consolidated destination → forcing stage 6");
            $updateBookingStatus['stage_id'] = 6;
        }

        // 4️⃣ Update booking stage/status
        $updateResponse = jsonRpcRequest($odooUrl, [
            'jsonrpc' => '2.0',
            'method' => 'call',
            'params' => [
                'service' => 'object',
                'method' => 'execute_kw',
                'args' => [
                    $db, $uid, $odooPassword,
                    'freight.management', 'write',
                    [[$bookingId], $updateBookingStatus]
                ]
            ],
            'id' => rand(1000, 9999)
        ]);

        Log::info("Updated booking status for bookingRef {$bookingRef}, bookingId: {$bookingId}", [
            'update' => $updateBookingStatus,
            'response' => $updateResponse
        ]);

        return $updateResponse;
    }



    public function uploadPOD(Request $request)
    {
        
        $url = $this->url;
        $db = $this->db;
        $uid = $request->query('uid') ;
        $odooPassword = $request->header('password');
        $images = $request->input('images');
        $signature = $request->input('signature');
        $transactionId = (int)$request->input('id');
        $dispatchType = $request->input('dispatch_type');
        $requestNumber = $request->input('request_number');
        $actualTime = $request->input('timestamp');
        $enteredName = $request->input('enteredName');
        $newStatus = $request->input('newStatus');
        $containerNumber = $request->input('enteredContainerNumber');
        $odooUrl = $this->odoo_url;

        $type = $this->handleDispatchRequest($request);
        if ($type instanceof \Illuminate\Http\JsonResponse) return $type;

        $serviceType = is_array($type['service_type']) ? $type['service_type'][0] : $type['service_type'];
        $updateField = $this->buildUpdateField1($type, $requestNumber, $images, $signature, $enteredName, $actualTime, $containerNumber, $newStatus, $serviceType);

        if (empty($updateField)) {
            return response()->json(['success' => false, 'message' => 'No matching update rules found'], 400);
        }
        
        $updateResponse = $this->updateDispatchRecord($transactionId, $updateField, $db, $uid, $odooPassword, $odooUrl);

        if (!($updateResponse['result'] ?? false)) {
            Log::error("Failed to insert image", ["response" => $updateResponse]);
            return response()->json(['success' => false, 'message' => 'Failed to upload POD'], 500);
        }

        $this->updateFFContainerNumber($type, $containerNumber, $db, $uid, $odooPassword, $odooUrl);

        $bookingRef = $type['booking_reference_no'] ?? null; // needed by divertedConsol

        if($type['pe_request_no'] == $requestNumber) {
            $this->divertedConsol($transactionId, $actualTime, $db, $uid, $odooPassword, $odooUrl, $bookingRef);
        }
        
       
        $milestoneResult = $this->getMilestoneHistory($transactionId, $db, $uid, $odooPassword, $odooUrl);
        if ($milestoneResult instanceof \Illuminate\Http\JsonResponse) return $milestoneResult;

        $milestoneCodeToUpdate = $this->resolveMilestoneCode($type, $requestNumber, $serviceType);  

        if(in_array($milestoneCodeToUpdate, ['TYOT', 'LCLOT'])) {
            $bookingRef = $type['booking_reference_no'] ?? null;
            if($bookingRef) {
                $this->updateBookingStage1($bookingRef, $db, $uid, $odooPassword, $odooUrl);
            }
        }

        if($milestoneCodeToUpdate === 'TLOT'){
            $notebookRes = jsonRpcRequest($odooUrl, [
                'jsonrpc' => '2.0',
                'method' => 'call',
                'params' => [
                    'service' => 'object',
                    'method' => 'execute_kw',
                    'args' => [$db, $uid, $odooPassword, 'consol.type.notebook', 'search_read',
                        [[['consol_origin', '=', $transactionId]]],
                        ['fields' => ['id', 'consolidation_id', 'consol_origin']]
                    ]
                ],
                'id' => rand(1000, 9999)
            ]);

            if (!empty($notebookRes['result'])) {
                foreach ($notebookRes['result'] as $nb) {
                    $consolMaster = $nb['consolidation_id'] ?? null;
                    $consolMasterId = is_array($consolMaster) && isset($consolMaster[0]) ? $consolMaster[0] : null;

                    $masterRes = jsonRpcRequest($odooUrl, [
                        'jsonrpc' => '2.0',
                        'method' => 'call',
                        'params' => [
                            'service' => 'object',
                            'method' => 'execute_kw',
                            'args' => [
                                $db,
                                $uid,
                                $odooPassword,
                                'pd.consol.master',
                                'search_read',
                                [[['id', '=', $consolMasterId]]],
                                ['fields' => ['id', 'status']]
                            ]
                        ],
                        'id' => rand(1000, 9999)
                    ]);

                    $master = $masterRes['result'][0] ?? null;
                    $status = strtolower($master['status'] ?? '');

                    if ($status === 'draft') {
                        Log::info('⏩ Skipping DRAFT first upload — status not consolidated', [
                            'consolMasterId' => $consolMasterId,
                            'status' => $status
                        ]);
                        continue; // Stop execution entirely
                    }

                    if ($consolMasterId) {
                        $updateConsolMaster = jsonRpcRequest($odooUrl, [
                            'jsonrpc' => '2.0',
                            'method' => 'call',
                            'params' => [
                                'service' => 'object',
                                'method' => 'execute_kw',
                                'args' => [$db, $uid, $odooPassword, 'pd.consol.master', 'write',
                                    [[$consolMasterId], ['status' => 'completed']]
                                ]
                            ],
                            'id' => rand(1000, 9999)
                        ]);

                        Log::info("✅ Consolidation master updated", [
                            'consolMasterId' => $consolMasterId,
                            'response' => $updateConsolMaster
                        ]);
                    } else {
                        Log::warning("⚠ consolidation_id missing in notebook record", ['notebook' => $nb]);
                    }
                }
            }else{
                Log::warning("No consolidation notebook for transactiom {$transactionId}");
            }
        }
        if ($milestoneCodeToUpdate) {
            return $this->updateMilestoneAndSendEmail(
                $milestoneResult,   // ✅ use the same variable
                $milestoneCodeToUpdate,
                $actualTime,
                $db,
                $uid,
                $odooPassword,
                $odooUrl
            );
        }
        return response()->json(['success' => true, 'message' => 'POD uploaded, but no matching milestone found']);

    }



    public function uploadPOD_sec(Request $request)
    {
        $url = $this->url;
        $db = $this->db;
        $uid = $request->query('uid') ;
        $odooPassword = $request->header('password');
        $images = $request->input('images');
        $signature = $request->input('signature');
        $transactionId = (int)$request->input('id');
        $dispatchType = $request->input('dispatch_type');
        $requestNumber = $request->input('request_number');
        $actualTime = $request->input('timestamp');

        $enteredName = $request->input('enteredName');
        $newStatus = $request->input('newStatus');
        $containerNumber = $request->input('enteredContainerNumber');
        $odooUrl = $this->odoo_url;


       
       

        $type = $this->handleDispatchRequest($request);
        if ($type instanceof \Illuminate\Http\JsonResponse) return $type;

        $serviceType = is_array($type['service_type']) ? $type['service_type'][0] : $type['service_type'];
        $result = $this->buildUpdateField2($type, $requestNumber, $images, $signature, $enteredName, $actualTime, $containerNumber, $newStatus, $serviceType);
        $updateField = $result['updateField'];
        $updateBookingStatus = $result['updateBookingStatus'];

        if (empty($updateField)) {
            return response()->json(['success' => false, 'message' => 'No matching update rules found'], 400);
        }
        
        $updateResponse = $this->updateDispatchRecord($transactionId, $updateField, $db, $uid, $odooPassword, $odooUrl);

        if (!($updateResponse['result'] ?? false)) {
            Log::error("Failed to insert image", ["response" => $updateResponse]);
            return response()->json(['success' => false, 'message' => 'Failed to upload POD'], 500);
        }

        $bookingRef = $type['booking_reference_no'] ?? null;

        $this->updateFFContainerNumber($type, $containerNumber, $db, $uid, $odooPassword, $odooUrl);

        $this->consolidationMaster($transactionId,$actualTime,$db,$uid,$odooPassword,$odooUrl, $bookingRef);
       
        $milestoneResult = $this->getMilestoneHistory($transactionId, $db, $uid, $odooPassword, $odooUrl);
        if ($milestoneResult instanceof \Illuminate\Http\JsonResponse) return $milestoneResult;

        $milestoneCodeToUpdate = $this->resolveMilestoneCode2($type, $requestNumber, $serviceType);  
        if (in_array($milestoneCodeToUpdate, ['CLOT', 'CLDT', 'TCLOT'])) {
            if ($bookingRef && !empty($updateBookingStatus)) {
                Log::info("Triggering updateBookingStatus for bookingRef {$bookingRef}", ["status" => $updateBookingStatus]);
                $this->updateBookingStatus($bookingRef, $db, $uid, $odooPassword, $odooUrl, $updateBookingStatus);
            } else {
                Log::warning("Skipped updateBookingStatus — missing bookingRef or empty updateBookingStatus");
            }
        }

        if($milestoneCodeToUpdate === 'CYDT') {
            $bookingRef = $type['booking_reference_no'] ?? null;
            if($bookingRef) {
                $this->updateBookingStage2($bookingRef, $db, $uid, $odooPassword, $odooUrl);
            }
        }


        if($milestoneCodeToUpdate === 'TEOT'){
            $notebookRes = jsonRpcRequest($odooUrl, [
                'jsonrpc' => '2.0',
                'method' => 'call',
                'params' => [
                    'service' => 'object',
                    'method' => 'execute_kw',
                    'args' => [$db, $uid, $odooPassword, 'consol.type.notebook', 'search_read',
                        [[['consol_origin', '=', $transactionId]]],
                        ['fields' => ['id', 'consolidation_id', 'consol_origin','type_consol']]
                    ]
                ],
                'id' => rand(1000, 9999)
            ]);

            if (!empty($notebookRes['result'])) {
                foreach ($notebookRes['result'] as $nb) {
                    $consolMaster = $nb['consolidation_id'] ?? null;
                    $consolMasterId = is_array($consolMaster) && isset($consolMaster[0]) ? $consolMaster[0] : null;
                    $consolType= is_array($nb['type_consol']) && isset($nb['type_consol'][0]) ? $nb['type_consol'][0] : null;

                    $masterRes = jsonRpcRequest($odooUrl, [
                        'jsonrpc' => '2.0',
                        'method' => 'call',
                        'params' => [
                            'service' => 'object',
                            'method' => 'execute_kw',
                            'args' => [
                                $db,
                                $uid,
                                $odooPassword,
                                'pd.consol.master',
                                'search_read',
                                [[['id', '=', $consolMasterId]]],
                                ['fields' => ['id', 'status']]
                            ]
                        ],
                        'id' => rand(1000, 9999)
                    ]);

                    $master = $masterRes['result'][0] ?? null;
                    $status = strtolower($master['status'] ?? '');

                    if ($status === 'draft') {
                        Log::info('⏩ Skipping DRAFT second upload— status not consolidated', [
                            'consolMasterId' => $consolMasterId,
                            'status' => $status
                        ]);
                        continue; // Stop execution entirely
                    }

                    if ($consolMasterId && $consolType == 2) {
                        $updateConsolMaster = jsonRpcRequest($odooUrl, [
                            'jsonrpc' => '2.0',
                            'method' => 'call',
                            'params' => [
                                'service' => 'object',
                                'method' => 'execute_kw',
                                'args' => [$db, $uid, $odooPassword, 'pd.consol.master', 'write',
                                    [[$consolMasterId], ['status' => 'completed']]
                                ]
                            ],
                            'id' => rand(1000, 9999)
                        ]);

                        Log::info("✅ Consolidation master updated", [
                            'consolMasterId' => $consolMasterId,
                            'response' => $updateConsolMaster
                        ]);
                    } else {
                        Log::warning("⚠ consolidation_id missing in notebook record", ['notebook' => $nb]);
                    }
                }
            }else{
                Log::warning("No consolidation notebook for transactio {$transactionId}");
            }
        }

        if ($milestoneCodeToUpdate) {
            return $this->updateMilestoneAndSendEmail(
                $milestoneResult,   // ✅ use the same variable
                $milestoneCodeToUpdate,
                $actualTime,
                $db,
                $uid,
                $odooPassword,
                $odooUrl
            );
        }
        return response()->json(['success' => true, 'message' => 'POD uploaded, but no matching milestone found']);
    }

    public function notifyShipperConsignee(Request $request)
    {
        
        $url = $this->url;
        $db = $this->db;
        $uid = $request->query('uid') ;
        $odooPassword = $request->header('password');
        $transactionId = (int)$request->input('id');
        $dispatchType = $request->input('dispatch_type');
        $requestNumber = $request->input('request_number');
        $actualTime = $request->input('timestamp');
        $odooUrl = $this->odoo_url;

        // ✅ UID validation (prevents Odoo TypeError)
        if (!$uid || !is_numeric($uid)) {
            Log::error("❌ Invalid or missing UID", ['uid' => $uid]);
            return response()->json([
                'success' => false,
                'message' => 'Invalid or missing UID. Please re-login.'
            ], 400);
        }
        $uid = (int) $uid;

        $type = $this->handleDispatchRequest($request);
        if ($type instanceof \Illuminate\Http\JsonResponse) return $type;

        $serviceType = is_array($type['service_type']) ? $type['service_type'][0] : $type['service_type'];
   
        $milestoneResult = $this->getMilestoneHistory($transactionId, $db, $uid, $odooPassword, $odooUrl);
        if ($milestoneResult instanceof \Illuminate\Http\JsonResponse) return $milestoneResult;
       
        $milestoneCodeToUpdate = $this->resolveMilestoneCode3($type, $requestNumber, $serviceType); 

        if ($milestoneCodeToUpdate) {
            return $this->updateMilestoneAndSendEmail(
                $milestoneResult,   // ✅ use the same variable
                $milestoneCodeToUpdate,
                $actualTime,
                $db,
                $uid,
                $odooPassword,
                $odooUrl
            );
        }
        return response()->json(['success' => true, 'message' => 'Email sending failed!']);
    }

}