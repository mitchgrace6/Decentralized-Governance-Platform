;; Decentralized Governance Platform - Part 2: Proposal Management
;; Functions for creating, managing, and closing proposals

;; Import constants and use core contract data
;; In practice, these would reference the deployed core contract

;; Submit a new proposal
(define-public (submit-proposal
  (title (string-utf8 100)) 
  (description (string-utf8 1000))
  (payload-contract principal)
  (payload-function (string-ascii 128))
  (payload-args (list 10 (string-utf8 100)))
  (is-quadratic bool)
  (options-count uint)
)
  (let
    (
      (proposal-id (var-get next-proposal-id))
      (user-balance (unwrap! (get-token-balance tx-sender) (err ERR-INSUFFICIENT-BALANCE)))
      (current-block block-height)
      (voting-starts-at-block (+ current-block u1))
      (voting-ends-at-block (+ voting-starts-at-block (var-get voting-period)))
      (execution-allowed-at-block (+ voting-ends-at-block (var-get execution-timelock)))
      (expires-at-block (+ execution-allowed-at-block (var-get proposal-expiration-period)))
    )
    
    ;; Check if user has enough tokens to submit proposal
    (asserts! (>= user-balance (var-get proposal-submission-threshold)) (err ERR-INSUFFICIENT-BALANCE))
    
    ;; Check if options count is valid
    (asserts! (<= options-count (var-get max-options-per-proposal)) (err ERR-INVALID-STATE))
    (asserts! (> options-count u0) (err ERR-INVALID-STATE))

     ;; Create proposal
    (map-set proposals
      { proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposer: tx-sender,
        status: PROPOSAL-STATUS-ACTIVE,
        created-at-block: current-block,
        voting-starts-at-block: voting-starts-at-block,
        voting-ends-at-block: voting-ends-at-block,
        execution-allowed-at-block: execution-allowed-at-block,
        expires-at-block: expires-at-block,
        payload-contract: payload-contract,
        payload-function: payload-function,
        payload-args: payload-args,
        yes-votes: u0,
        no-votes: u0,
        abstain-votes: u0,
        executed-at-block: none,
        is-quadratic: is-quadratic,
        options-count: options-count
      }
    )
    
    ;; Initialize options if more than standard yes/no/abstain
    (if (> options-count u3)
      (begin
        ;; Initialize standard options
        (map-set proposal-options 
          { proposal-id: proposal-id, option-id: u1 } 
          { option-name: "Yes", option-description: "Approve the proposal", votes: u0 }
        )
        (map-set proposal-options 
          { proposal-id: proposal-id, option-id: u2 } 
          { option-name: "No", option-description: "Reject the proposal", votes: u0 }
        )
        (map-set proposal-options 
          { proposal-id: proposal-id, option-id: u3 } 
          { option-name: "Abstain", option-description: "Abstain from voting", votes: u0 }
        )
      )
      ;; For standard yes/no/abstain, we just rely on the counts in the proposal record
      true
    )
    
    ;; Increment proposal ID counter
    (var-set next-proposal-id (+ proposal-id u1))
    
    (ok proposal-id)
  )
)

;; Set option details when proposal has custom options
(define-public (set-proposal-option
  (proposal-id uint)
  (option-id uint)
  (option-name (string-utf8 100))
  (option-description (string-utf8 500))
)
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
    )
    
    ;; Check if caller is the proposer
    (asserts! (is-eq tx-sender (get proposer proposal)) (err ERR-NOT-AUTHORIZED))
    
    ;; Check if option id is valid
    (asserts! (<= option-id (get options-count proposal)) (err ERR-INVALID-STATE))
    (asserts! (> option-id u0) (err ERR-INVALID-STATE))
    
    ;; Check if proposal is still pending or just became active
    (asserts! (<= block-height (+ (get created-at-block proposal) u10)) (err ERR-INVALID-STATE))
    
    ;; Set option details
    (map-set proposal-options
      { proposal-id: proposal-id, option-id: option-id }
      {
        option-name: option-name,
        option-description: option-description,
        votes: u0
      }
    )
    
    (ok true)
  )
)

;; Close voting on a proposal and determine the outcome
(define-public (close-voting (proposal-id uint))
  (let
    (
      (proposal (unwrap! (get-proposal proposal-id) (err ERR-PROPOSAL-NOT-FOUND)))
      (current-block block-height)
    )
    
    ;; Check if proposal is active
    (asserts! (is-eq (get status proposal) PROPOSAL-STATUS-ACTIVE) (err ERR-INVALID-STATE))
    
    ;; Check if voting period has ended
    (asserts! (> current-block (get voting-ends-at-block proposal)) (err ERR-VOTING-ACTIVE))
    
    ;; Calculate outcome
    (let
      (
        (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
        (yes-percentage (if (> total-votes u0)
                         (/ (* (get yes-votes proposal) u100) total-votes)
                         u0))
        (new-status (if (>= yes-percentage (var-get proposal-approval-threshold))
                     PROPOSAL-STATUS-APPROVED
                     PROPOSAL-STATUS-REJECTED))
      )
      
      ;; Check minimum votes requirement (could add a separate threshold)
      (asserts! (> total-votes u0) (err ERR-INSUFFICIENT-VOTES))
      
      ;; Update proposal status
      (map-set proposals
        { proposal-id: proposal-id }
        (merge proposal { status: new-status })
      )
      
      (ok new-status)
    )
  )
) 