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

