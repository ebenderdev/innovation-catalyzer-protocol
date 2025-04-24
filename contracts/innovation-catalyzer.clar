;;  Innovation Catalyzer Protocol 

;; -----------------------------
;; Data Storage Architecture
;; -----------------------------

;; Primary initiative data repository
(define-map InitiativeArchive
  { initiative-id: uint }
  {
    originator: principal,
    required-resources: uint,
    gathered-resources: uint,
    conclusion-height: uint,
    initiative-phase: (string-ascii 10)
  }
)

;; Participant contribution ledger
(define-map ParticipantLedger
  { initiative-id: uint, participant: principal }
  { resources-committed: uint }
)

;; Protocol tracking variables
(define-data-var initiative-sequence uint u0)

;; Time boundaries for significant operations
(define-constant COOLING_PERIOD u144) 
(define-constant SIGNIFICANT_ALLOCATION_LEVEL u1000000000)
(define-constant MAXIMUM_PARTICIPANT_COMMITMENT u50000000000) 
(define-constant BLOCKS_IN_DAY u144)
(define-constant VELOCITY_WINDOW u72) 
(define-constant VELOCITY_THRESHOLD u5) 

;; Core configuration parameters
(define-constant ECOSYSTEM_STEWARD tx-sender)
(define-constant INITIATIVE_DURATION u2016) 

;; Response code definitions
(define-constant ERR_PERMISSION_RESTRICTED (err u200))
(define-constant ERR_INITIATIVE_NOT_FOUND (err u201))
(define-constant ERR_INVALID_ALLOCATION (err u202))
(define-constant ERR_INITIATIVE_SEALED (err u203))
(define-constant ERR_ALLOCATION_TARGET_UNACHIEVED (err u204))
(define-constant ERR_OPERATION_FAILED (err u205))
(define-constant ERR_ALLOCATION_LIMIT_EXCEEDED (err u206))
(define-constant ERR_REDEMPTION_UNAVAILABLE (err u212))
(define-constant ERR_NOTHING_TO_REDEEM (err u213))
(define-constant ERR_TRANSFER_STEWARDSHIP_FAILED (err u214))
(define-constant ERR_WITHDRAWAL_THRESHOLD_EXCEEDED (err u216))
(define-constant ERR_VELOCITY_LIMIT_EXCEEDED (err u220))


;; -----------------------------
;; Core Utility Functions
;; -----------------------------

;; Validates existence of an initiative
(define-private (initiative-registered (initiative-id uint))
  (<= initiative-id (var-get initiative-sequence))
)

;; Verifies initiative eligibility for resource allocation
(define-private (is-initiative-active (initiative-phase (string-ascii 10)))
  (is-eq initiative-phase "active")
)

;; -----------------------------
;; Participant Operations
;; -----------------------------

;; Enables participants to commit resources to initiatives
(define-public (commit-resources (initiative-id uint) (resource-amount uint))
  (begin
    (asserts! (> resource-amount u0) (err ERR_INVALID_ALLOCATION))
    (asserts! (initiative-registered initiative-id) (err ERR_INITIATIVE_NOT_FOUND))
    (let
      (
        (initiative-record (unwrap! (map-get? InitiativeArchive { initiative-id: initiative-id }) (err ERR_INITIATIVE_NOT_FOUND)))
        (current-phase (get initiative-phase initiative-record))
        (allocation-sum (get gathered-resources initiative-record))
        (updated-sum (+ allocation-sum resource-amount))
      )
      (asserts! (is-initiative-active current-phase) (err ERR_INITIATIVE_SEALED))
      (asserts! (<= block-height (get conclusion-height initiative-record)) (err ERR_INITIATIVE_SEALED))
      (match (stx-transfer? resource-amount tx-sender (as-contract tx-sender))
        success
          (begin
            (map-set InitiativeArchive
              { initiative-id: initiative-id }
              (merge initiative-record { gathered-resources: updated-sum })
            )
            (map-set ParticipantLedger
              { initiative-id: initiative-id, participant: tx-sender }
              { resources-committed: resource-amount }
            )
            (print {event: "resource_commitment", initiative-id: initiative-id, participant: tx-sender, amount: resource-amount})
            (ok true)
          )
        error (err ERR_OPERATION_FAILED)
      )
    )
  )
)

;; Enhanced resource commitment with safeguards
(define-public (secure-resource-commitment (initiative-id uint) (resource-amount uint))
  (begin
    (asserts! (> resource-amount u0) (err ERR_INVALID_ALLOCATION))
    (asserts! (<= resource-amount MAXIMUM_PARTICIPANT_COMMITMENT) (err ERR_ALLOCATION_LIMIT_EXCEEDED))
    (asserts! (initiative-registered initiative-id) (err ERR_INITIATIVE_NOT_FOUND))
    (let
      (
        (initiative-record (unwrap! (map-get? InitiativeArchive { initiative-id: initiative-id }) (err ERR_INITIATIVE_NOT_FOUND)))
        (current-phase (get initiative-phase initiative-record))
        (allocation-sum (get gathered-resources initiative-record))
        (updated-sum (+ allocation-sum resource-amount))
        (participant-history (default-to { resources-committed: u0 } 
                          (map-get? ParticipantLedger { initiative-id: initiative-id, participant: tx-sender })))
        (previous-commitment (get resources-committed participant-history))
        (total-participant-commitment (+ previous-commitment resource-amount))
      )
      ;; Validate participant commitment limits
      (asserts! (<= total-participant-commitment MAXIMUM_PARTICIPANT_COMMITMENT) (err ERR_ALLOCATION_LIMIT_EXCEEDED))
      (asserts! (is-initiative-active current-phase) (err ERR_INITIATIVE_SEALED))
      (asserts! (<= block-height (get conclusion-height initiative-record)) (err ERR_INITIATIVE_SEALED))

      (match (stx-transfer? resource-amount tx-sender (as-contract tx-sender))
        success
          (begin
            (map-set InitiativeArchive
              { initiative-id: initiative-id }
              (merge initiative-record { gathered-resources: updated-sum })
            )
            (map-set ParticipantLedger
              { initiative-id: initiative-id, participant: tx-sender }
              { resources-committed: total-participant-commitment }
            )
            (print {event: "secured_commitment", initiative-id: initiative-id, participant: tx-sender, amount: resource-amount})
            (ok true)
          )
        error (err ERR_OPERATION_FAILED)
      )
    )
  )
)



