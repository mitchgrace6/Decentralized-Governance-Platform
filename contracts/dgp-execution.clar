;; Decentralized Governance Platform - Part 4: Execution and Administration
;; Functions for executing proposals, treasury management, and administration

;; Execute an approved proposal
(define-public (execute-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
      (current-block block-height)
    )
    
    ;; Check if proposal is approved
    (asserts! (is-eq (get status proposal) PROPOSAL-STATUS-APPROVED) (err ERR-INVALID-STATE))
    
    ;; Check if timelock has passed
    (asserts! (>= current-block (get execution-allowed-at-block proposal)) (err ERR-EXECUTION-TIMELOCK-ACTIVE))
    
    ;; Check if proposal hasn't expired
    (asserts! (< current-block (get expires-at-block proposal)) (err ERR-PROPOSAL-EXPIRED))
    
    ;; Check if proposal hasn't already been executed
    (asserts! (is-none (get executed-at-block proposal)) (err ERR-ALREADY-EXECUTED))
    
    ;; Execute proposal by calling the specified contract function
    ;; Note: In an actual implementation, this would use dynamic contract calls
    ;; For this example, we're just registering that execution was attempted
    
    ;; Update proposal as executed
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { 
        status: PROPOSAL-STATUS-EXECUTED,
        executed-at-block: (some current-block)
      })
    )
    
    (ok true)
  )
)

;; Treasury functions

;; Deposit tokens to the treasury
(define-public (deposit-to-treasury (amount uint))
  (let
    (
      (current-balance (var-get treasury-balance))
    )
    
    ;; Transfer tokens from sender to contract
    (try! (contract-call? (var-get governance-token-contract) transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update treasury balance
    (var-set treasury-balance (+ current-balance amount))
    
    (ok true)
  )
)

;; Withdraw tokens from treasury (only via successful proposal)
(define-public (withdraw-from-treasury (amount uint) (recipient principal) (proposal-id uint))
  (let
    (
      (current-balance (var-get treasury-balance))
      (proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
    )
    
    ;; Only contract itself can call this (from a proposal execution)
    (asserts! (is-eq tx-sender (as-contract tx-sender)) (err ERR-NOT-AUTHORIZED))
    
    ;; Check if proposal is executed
    (asserts! (is-eq (get status proposal) PROPOSAL-STATUS-EXECUTED) (err ERR-INVALID-STATE))
    
    ;; Check if treasury has enough balance
    (asserts! (>= current-balance amount) (err ERR-INSUFFICIENT-BALANCE))
    
    ;; Transfer tokens from contract to recipient
    (try! (as-contract (contract-call? (var-get governance-token-contract) transfer amount tx-sender recipient none)))
    
    ;; Update treasury balance
    (var-set treasury-balance (- current-balance amount))
    
    (ok true)
  )
)

;; Administrative functions

;; Update governance token contract (only owner)
(define-public (update-governance-token (new-token-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (var-set governance-token-contract new-token-contract)
    (ok true)
  )
)

;; Update DAO parameters (only owner)
(define-public (update-dao-parameters
  (new-dao-name (string-utf8 100))
  (new-proposal-submission-threshold uint)
  (new-voting-period uint)
  (new-execution-timelock uint)
  (new-proposal-expiration-period uint)
  (new-proposal-approval-threshold uint)
  (new-quadratic-voting-enabled bool)
  (new-max-options-per-proposal uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    
    (var-set dao-name new-dao-name)
    (var-set proposal-submission-threshold new-proposal-submission-threshold)
    (var-set voting-period new-voting-period)
    (var-set execution-timelock new-execution-timelock)
    (var-set proposal-expiration-period new-proposal-expiration-period)
    (var-set proposal-approval-threshold new-proposal-approval-threshold)
    (var-set quadratic-voting-enabled new-quadratic-voting-enabled)
    (var-set max-options-per-proposal new-max-options-per-proposal)
    
    (ok true)
  )
)

;; Transfer ownership (only owner)
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
) 