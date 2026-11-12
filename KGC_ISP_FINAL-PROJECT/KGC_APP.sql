/* =========================================================
   KGC_APPv2 - DATABASE SETUP & STORED PROCEDURES
   ========================================================= */

USE master;
GO

IF DB_ID(N'KGC_ISP') IS NULL
BEGIN
    CREATE DATABASE KGC_ISPV2;
END;
GO

USE KGC_ISPV2;
GO

/* =========================================================
   1. MASTER ITEM TABLE
   ========================================================= */

CREATE TABLE dbo.Items
(
    ItemID INT IDENTITY(1,1) NOT NULL,
    ItemCode NVARCHAR(30) NOT NULL,
    ItemName NVARCHAR(150) NOT NULL,
    Description NVARCHAR(500) NULL,
    Unit NVARCHAR(30) NOT NULL
        CONSTRAINT DF_Items_Unit DEFAULT ('pcs'),
    CurrentStock DECIMAL(18,2) NOT NULL
        CONSTRAINT DF_Items_CurrentStock DEFAULT (0),
    MinimumStockLevel DECIMAL(18,2) NOT NULL
        CONSTRAINT DF_Items_MinimumStockLevel DEFAULT (0),
    UnitCost DECIMAL(18,2) NOT NULL
        CONSTRAINT DF_Items_UnitCost DEFAULT (0),
    IsActive BIT NOT NULL
        CONSTRAINT DF_Items_IsActive DEFAULT (1),

    CONSTRAINT PK_Items PRIMARY KEY (ItemID),
    CONSTRAINT UQ_Items_ItemCode UNIQUE (ItemCode),
    CONSTRAINT CK_Items_CurrentStock CHECK (CurrentStock >= 0),
    CONSTRAINT CK_Items_MinimumStockLevel CHECK (MinimumStockLevel >= 0),
    CONSTRAINT CK_Items_UnitCost CHECK (UnitCost >= 0)
);
GO

/* =========================================================
   2. REQUISITION HEADER TABLE
   ========================================================= */

CREATE TABLE dbo.Requisitions
(
    RequisitionID INT IDENTITY(1,1) NOT NULL,
    RequisitionNo NVARCHAR(30) NOT NULL,
    Department NVARCHAR(100) NOT NULL,
    RequestedBy NVARCHAR(120) NOT NULL,
    RequestDate DATETIME2(0) NOT NULL
        CONSTRAINT DF_Requisitions_RequestDate DEFAULT (SYSDATETIME()),
    Status NVARCHAR(50) NOT NULL
        CONSTRAINT DF_Requisitions_Status DEFAULT ('Pending'),
    PriorityNotes NVARCHAR(500) NULL,

    CONSTRAINT PK_Requisitions PRIMARY KEY (RequisitionID),
    CONSTRAINT UQ_Requisitions_RequisitionNo UNIQUE (RequisitionNo),
    CONSTRAINT CK_Requisitions_Status CHECK
    (
        Status IN
        (
            'Pending',
            'Approved',
            'Rejected',
            'Awaiting Purchasing & Delivery',
            'Ready for Release',
            'Completed'
        )
    )
);
GO

/* =========================================================
   3. REQUISITION LINE ITEMS
   ========================================================= */

CREATE TABLE dbo.RequisitionItems
(
    RequisitionItemID INT IDENTITY(1,1) NOT NULL,
    RequisitionID INT NOT NULL,
    ItemID INT NOT NULL,
    Quantity DECIMAL(18,2) NOT NULL,

    CONSTRAINT PK_RequisitionItems PRIMARY KEY (RequisitionItemID),
    CONSTRAINT FK_RequisitionItems_Requisitions
        FOREIGN KEY (RequisitionID)
        REFERENCES dbo.Requisitions(RequisitionID),
    CONSTRAINT FK_RequisitionItems_Items
        FOREIGN KEY (ItemID)
        REFERENCES dbo.Items(ItemID),
    CONSTRAINT CK_RequisitionItems_Quantity CHECK (Quantity > 0)
);
GO

/* =========================================================
   4. PURCHASE REQUESTS
   ========================================================= */

CREATE TABLE dbo.PurchaseRequests
(
    PurchaseRequestID INT IDENTITY(1,1) NOT NULL,
    SourceType NVARCHAR(60) NOT NULL,
    SourceRequisitionID INT NULL,
    ItemID INT NOT NULL,
    RequestedQty DECIMAL(18,2) NOT NULL,
    PurchasingStatus NVARCHAR(60) NOT NULL
        CONSTRAINT DF_PurchaseRequests_PurchasingStatus DEFAULT ('Open'),
    CreatedAt DATETIME2(0) NOT NULL
        CONSTRAINT DF_PurchaseRequests_CreatedAt DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_PurchaseRequests PRIMARY KEY (PurchaseRequestID),
    CONSTRAINT FK_PurchaseRequests_Requisitions
        FOREIGN KEY (SourceRequisitionID)
        REFERENCES dbo.Requisitions(RequisitionID),
    CONSTRAINT FK_PurchaseRequests_Items
        FOREIGN KEY (ItemID)
        REFERENCES dbo.Items(ItemID),
    CONSTRAINT CK_PurchaseRequests_RequestedQty CHECK (RequestedQty > 0),
    CONSTRAINT CK_PurchaseRequests_PurchasingStatus CHECK
    (
        PurchasingStatus IN
        (
            'Open',
            'Failed - Retry',
            'Order Placed & Verified',
            'Closed'
        )
    )
);
GO

/* =========================================================
   5. PURCHASE ORDERS
   ========================================================= */

CREATE TABLE dbo.PurchaseOrders
(
    PurchaseOrderID INT IDENTITY(1,1) NOT NULL,
    PurchaseRequestID INT NOT NULL,
    SellerPlatform NVARCHAR(20) NOT NULL,
    SellerName NVARCHAR(150) NOT NULL,
    SellerItemDetails NVARCHAR(300) NULL,
    TrackingNumber NVARCHAR(100) NULL,
    OrderedQty DECIMAL(18,2) NOT NULL,
    PurchasingStatus NVARCHAR(60) NOT NULL,
    OrderDate DATETIME2(0) NOT NULL
        CONSTRAINT DF_PurchaseOrders_OrderDate DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_PurchaseOrders PRIMARY KEY (PurchaseOrderID),
    CONSTRAINT FK_PurchaseOrders_PurchaseRequests
        FOREIGN KEY (PurchaseRequestID)
        REFERENCES dbo.PurchaseRequests(PurchaseRequestID),
    CONSTRAINT CK_PurchaseOrders_SellerPlatform CHECK
    (
        SellerPlatform IN ('Shopee', 'Lazada')
    ),
    CONSTRAINT CK_PurchaseOrders_OrderedQty CHECK (OrderedQty > 0),
    CONSTRAINT CK_PurchaseOrders_PurchasingStatus CHECK
    (
        PurchasingStatus IN
        (
            'Failed - Retry',
            'Order Placed & Verified'
        )
    )
);
GO

/* =========================================================
   6. DELIVERY RECORDS
   ========================================================= */

CREATE TABLE dbo.Deliveries
(
    DeliveryID INT IDENTITY(1,1) NOT NULL,
    PurchaseOrderID INT NOT NULL,
    TrackingNumber NVARCHAR(100) NOT NULL,
    DeliveryStatus NVARCHAR(80) NOT NULL
        CONSTRAINT DF_Deliveries_DeliveryStatus DEFAULT ('In Transit'),
    ReceivedQty DECIMAL(18,2) NULL,
    InspectionNotes NVARCHAR(500) NULL,
    UpdatedAt DATETIME2(0) NOT NULL
        CONSTRAINT DF_Deliveries_UpdatedAt DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_Deliveries PRIMARY KEY (DeliveryID),
    CONSTRAINT FK_Deliveries_PurchaseOrders
        FOREIGN KEY (PurchaseOrderID)
        REFERENCES dbo.PurchaseOrders(PurchaseOrderID),
    CONSTRAINT CK_Deliveries_DeliveryStatus CHECK
    (
        DeliveryStatus IN
        (
            'In Transit',
            'Issue Reported - Refund/Replacement',
            'Delivery Confirmed & Verified'
        )
    ),
    CONSTRAINT CK_Deliveries_ReceivedQty CHECK
    (
        ReceivedQty IS NULL OR ReceivedQty >= 0
    )
);
GO

/* =========================================================
   7. INVENTORY TRANSACTION LEDGER
   ========================================================= */

CREATE TABLE dbo.InventoryTransactions
(
    InventoryTransactionID BIGINT IDENTITY(1,1) NOT NULL,
    ItemID INT NOT NULL,
    TransactionType NVARCHAR(20) NOT NULL,
    Quantity DECIMAL(18,2) NOT NULL,
    ReferenceType NVARCHAR(40) NOT NULL,
    ReferenceID INT NULL,
    BalanceAfter DECIMAL(18,2) NOT NULL,
    TransactionDate DATETIME2(0) NOT NULL
        CONSTRAINT DF_InventoryTransactions_TransactionDate DEFAULT (SYSDATETIME()),
    Notes NVARCHAR(500) NULL,

    CONSTRAINT PK_InventoryTransactions PRIMARY KEY (InventoryTransactionID),
    CONSTRAINT FK_InventoryTransactions_Items
        FOREIGN KEY (ItemID)
        REFERENCES dbo.Items(ItemID),
    CONSTRAINT CK_InventoryTransactions_TransactionType CHECK
    (
        TransactionType IN ('Stock In', 'Stock Out')
    ),
    CONSTRAINT CK_InventoryTransactions_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_InventoryTransactions_BalanceAfter CHECK (BalanceAfter >= 0)
);
GO

/* =========================================================
   8. INDEXES
   ========================================================= */

CREATE INDEX IX_Requisitions_Status_RequestDate
    ON dbo.Requisitions(Status, RequestDate DESC);
GO

CREATE INDEX IX_PurchaseRequests_Status_CreatedAt
    ON dbo.PurchaseRequests(PurchasingStatus, CreatedAt);
GO

CREATE INDEX IX_PurchaseOrders_PurchaseRequestID
    ON dbo.PurchaseOrders(PurchaseRequestID);
GO

CREATE INDEX IX_Deliveries_PurchaseOrderID_Status
    ON dbo.Deliveries(PurchaseOrderID, DeliveryStatus);
GO

CREATE INDEX IX_InventoryTransactions_ItemID_TransactionDate
    ON dbo.InventoryTransactions(ItemID, TransactionDate DESC);
GO

/* =========================================================
   9. VIEWS
   ========================================================= */

CREATE VIEW dbo.vw_LowStockItems
AS
    SELECT
        ItemID,
        ItemCode,
        ItemName,
        Unit,
        CurrentStock,
        MinimumStockLevel,
        UnitCost,
        CASE
            WHEN CurrentStock <= MinimumStockLevel THEN 1
            ELSE 0
        END AS IsLowStock
    FROM dbo.Items
    WHERE IsActive = 1;
GO

CREATE VIEW dbo.vw_OpenPurchaseRequests
AS
    SELECT
        PR.PurchaseRequestID,
        PR.SourceType,
        PR.SourceRequisitionID,
        PR.ItemID,
        I.ItemCode,
        I.ItemName,
        PR.RequestedQty,
        PR.PurchasingStatus,
        PR.CreatedAt
    FROM dbo.PurchaseRequests AS PR
    INNER JOIN dbo.Items AS I
        ON PR.ItemID = I.ItemID
    WHERE PR.PurchasingStatus IN ('Open', 'Failed - Retry');
GO

CREATE VIEW dbo.vw_DeliveryVerification
AS
    SELECT
        D.DeliveryID,
        PO.PurchaseOrderID,
        PR.PurchaseRequestID,
        PR.SourceRequisitionID,
        I.ItemCode,
        I.ItemName,
        D.TrackingNumber,
        PO.PurchasingStatus,
        D.DeliveryStatus,
        PO.OrderedQty,
        D.ReceivedQty,
        CASE
            WHEN PO.PurchasingStatus = 'Order Placed & Verified'
             AND D.DeliveryStatus = 'Delivery Confirmed & Verified'
            THEN 1
            ELSE 0
        END AS DualGatePassed
    FROM dbo.Deliveries AS D
    INNER JOIN dbo.PurchaseOrders AS PO
        ON D.PurchaseOrderID = PO.PurchaseOrderID
    INNER JOIN dbo.PurchaseRequests AS PR
        ON PO.PurchaseRequestID = PR.PurchaseRequestID
    INNER JOIN dbo.Items AS I
        ON PR.ItemID = I.ItemID;
GO

CREATE VIEW dbo.vw_RequisitionSummary
AS
    SELECT
        R.RequisitionID,
        R.RequisitionNo,
        R.Department,
        R.RequestedBy,
        R.RequestDate,
        R.Status,
        R.PriorityNotes,
        COUNT(RI.RequisitionItemID) AS LineCount,
        COALESCE(SUM(RI.Quantity), 0) AS TotalRequestedQuantity
    FROM dbo.Requisitions AS R
    LEFT JOIN dbo.RequisitionItems AS RI
        ON R.RequisitionID = RI.RequisitionID
    GROUP BY
        R.RequisitionID,
        R.RequisitionNo,
        R.Department,
        R.RequestedBy,
        R.RequestDate,
        R.Status,
        R.PriorityNotes;
GO

CREATE VIEW dbo.vw_InventoryLedger
AS
    SELECT
        T.InventoryTransactionID,
        T.ItemID,
        I.ItemCode,
        I.ItemName,
        T.TransactionType,
        T.Quantity,
        T.ReferenceType,
        T.ReferenceID,
        T.BalanceAfter,
        T.TransactionDate,
        T.Notes
    FROM dbo.InventoryTransactions AS T
    INNER JOIN dbo.Items AS I
        ON T.ItemID = I.ItemID;
GO

/* =========================================================
   10. STORED PROCEDURES
   ========================================================= */

CREATE PROCEDURE dbo.sp_AddItem
    @ItemCode NVARCHAR(30),
    @ItemName NVARCHAR(150),
    @Description NVARCHAR(500) = NULL,
    @Unit NVARCHAR(30) = 'pcs',
    @UnitCost DECIMAL(18,2) = 0,
    @MinimumStockLevel DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.Items WHERE ItemCode = @ItemCode)
    BEGIN
        THROW 50001, 'Item code already exists.', 1;
    END;

    INSERT INTO dbo.Items
    (
        ItemCode, ItemName, Description, Unit, CurrentStock, MinimumStockLevel, UnitCost, IsActive
    )
    VALUES
    (
        @ItemCode, @ItemName, @Description, @Unit, 0, @MinimumStockLevel, @UnitCost, 1
    );

    SELECT SCOPE_IDENTITY() AS NewItemID;
END;
GO

CREATE PROCEDURE dbo.sp_UpdateItem
    @ItemID INT,
    @ItemCode NVARCHAR(30),
    @ItemName NVARCHAR(150),
    @Description NVARCHAR(500) = NULL,
    @Unit NVARCHAR(30),
    @MinimumStockLevel DECIMAL(18,2),
    @UnitCost DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Items WHERE ItemID = @ItemID)
    BEGIN
        THROW 50002, 'Item not found.', 1;
    END;

    IF EXISTS (SELECT 1 FROM dbo.Items WHERE ItemCode = @ItemCode AND ItemID <> @ItemID)
    BEGIN
        THROW 50003, 'Item code already exists.', 1;
    END;

    UPDATE dbo.Items
    SET
        ItemCode = @ItemCode,
        ItemName = @ItemName,
        Description = @Description,
        Unit = @Unit,
        MinimumStockLevel = @MinimumStockLevel,
        UnitCost = @UnitCost
    WHERE ItemID = @ItemID;

    SELECT 'Item updated successfully.' AS Message;
END;
GO

CREATE PROCEDURE dbo.sp_DeactivateItem
    @ItemID INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Items
    SET IsActive = 0
    WHERE ItemID = @ItemID;

    IF @@ROWCOUNT = 0
        THROW 50004, 'Item not found.', 1;

    SELECT 'Item deactivated successfully.' AS Message;
END;
GO

CREATE PROCEDURE dbo.sp_CreateRequisition
    @RequisitionNo NVARCHAR(30),
    @Department NVARCHAR(100),
    @RequestedBy NVARCHAR(120),
    @PriorityNotes NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Requisitions
    (
        RequisitionNo, Department, RequestedBy, Status, PriorityNotes
    )
    VALUES
    (
        @RequisitionNo, @Department, @RequestedBy, 'Pending', @PriorityNotes
    );

    SELECT SCOPE_IDENTITY() AS NewRequisitionID;
END;
GO

CREATE PROCEDURE dbo.sp_AddRequisitionItem
    @RequisitionID INT,
    @ItemID INT,
    @Quantity DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Requisitions WHERE RequisitionID = @RequisitionID AND Status = 'Pending')
    BEGIN
        THROW 50005, 'Requisition not found or is no longer pending.', 1;
    END;

    IF NOT EXISTS (SELECT 1 FROM dbo.Items WHERE ItemID = @ItemID AND IsActive = 1)
    BEGIN
        THROW 50006, 'Item does not exist or is inactive.', 1;
    END;

    IF @Quantity <= 0
        THROW 50007, 'Quantity must be greater than zero.', 1;

    INSERT INTO dbo.RequisitionItems (RequisitionID, ItemID, Quantity)
    VALUES (@RequisitionID, @ItemID, @Quantity);

    SELECT 'Item added to requisition.' AS Message;
END;
GO

CREATE PROCEDURE dbo.sp_ApproveRequisition
    @RequisitionID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Requisitions WITH (UPDLOCK, HOLDLOCK) WHERE RequisitionID = @RequisitionID AND Status = 'Pending')
        BEGIN
            THROW 50008, 'Requisition is not pending or does not exist.', 1;
        END;

        IF NOT EXISTS (SELECT 1 FROM dbo.RequisitionItems WHERE RequisitionID = @RequisitionID)
        BEGIN
            THROW 50009, 'Requisition has no items.', 1;
        END;

        DECLARE @Shortages TABLE (ItemID INT, ShortageQty DECIMAL(18,2));

        INSERT INTO @Shortages (ItemID, ShortageQty)
        SELECT RI.ItemID, SUM(RI.Quantity) - I.CurrentStock
        FROM dbo.RequisitionItems RI
        INNER JOIN dbo.Items I ON RI.ItemID = I.ItemID
        WHERE RI.RequisitionID = @RequisitionID
        GROUP BY RI.ItemID, I.CurrentStock
        HAVING SUM(RI.Quantity) > I.CurrentStock;

        IF EXISTS (SELECT 1 FROM @Shortages)
        BEGIN
            INSERT INTO dbo.PurchaseRequests (SourceType, SourceRequisitionID, ItemID, RequestedQty, PurchasingStatus)
            SELECT 'Requisition Shortage', @RequisitionID, ItemID, ShortageQty, 'Open'
            FROM @Shortages;

            UPDATE dbo.Requisitions
            SET Status = 'Awaiting Purchasing & Delivery'
            WHERE RequisitionID = @RequisitionID;

            COMMIT TRANSACTION;
            SELECT 'Insufficient stock. Purchase requests created.' AS Message;
        END
        ELSE
        BEGIN
            UPDATE dbo.Requisitions
            SET Status = 'Approved'
            WHERE RequisitionID = @RequisitionID;

            COMMIT TRANSACTION;
            SELECT 'Requisition approved successfully.' AS Message;
        END;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.sp_RejectRequisition
    @RequisitionID INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Requisitions
    SET Status = 'Rejected'
    WHERE RequisitionID = @RequisitionID AND Status = 'Pending';

    IF @@ROWCOUNT = 0
        THROW 50010, 'Requisition not found or cannot be rejected.', 1;

    SELECT 'Requisition rejected successfully.' AS Message;
END;
GO

CREATE PROCEDURE dbo.sp_CreatePurchaseOrder
    @PurchaseRequestID INT,
    @SellerPlatform NVARCHAR(20),
    @SellerName NVARCHAR(150),
    @SellerItemDetails NVARCHAR(300) = NULL,
    @TrackingNumber NVARCHAR(100),
    @OrderedQty DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @SellerPlatform NOT IN ('Shopee', 'Lazada')
            THROW 50011, 'Invalid seller platform.', 1;

        IF @OrderedQty <= 0
            THROW 50012, 'Ordered quantity must be greater than zero.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseRequests WITH (UPDLOCK, HOLDLOCK) WHERE PurchaseRequestID = @PurchaseRequestID AND PurchasingStatus IN ('Open', 'Failed - Retry'))
        BEGIN
            THROW 50013, 'Purchase request not found or cannot be processed.', 1;
        END;

        INSERT INTO dbo.PurchaseOrders
        (
            PurchaseRequestID, SellerPlatform, SellerName, SellerItemDetails, TrackingNumber, OrderedQty, PurchasingStatus
        )
        VALUES
        (
            @PurchaseRequestID, @SellerPlatform, @SellerName, @SellerItemDetails, @TrackingNumber, @OrderedQty, 'Order Placed & Verified'
        );

        DECLARE @NewPurchaseOrderID INT = SCOPE_IDENTITY();

        INSERT INTO dbo.Deliveries (PurchaseOrderID, TrackingNumber, DeliveryStatus)
        VALUES (@NewPurchaseOrderID, @TrackingNumber, 'In Transit');

        UPDATE dbo.PurchaseRequests
        SET PurchasingStatus = 'Order Placed & Verified'
        WHERE PurchaseRequestID = @PurchaseRequestID;

        COMMIT TRANSACTION;

        SELECT @NewPurchaseOrderID AS PurchaseOrderID, SCOPE_IDENTITY() AS DeliveryID, 'Purchase order created successfully.' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.sp_VerifyPurchaseOrder
    @PurchaseOrderID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.PurchaseOrders
        SET PurchasingStatus = 'Order Placed & Verified'
        WHERE PurchaseOrderID = @PurchaseOrderID AND PurchasingStatus = 'Failed - Retry';

        IF @@ROWCOUNT = 0
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.PurchaseOrders WHERE PurchaseOrderID = @PurchaseOrderID AND PurchasingStatus = 'Order Placed & Verified')
            BEGIN
                THROW 50014, 'Purchase order not found or cannot be verified.', 1;
            END;
        END;

        DECLARE @PurchaseRequestID INT;
        SELECT @PurchaseRequestID = PurchaseRequestID FROM dbo.PurchaseOrders WHERE PurchaseOrderID = @PurchaseOrderID;

        UPDATE dbo.PurchaseRequests
        SET PurchasingStatus = 'Order Placed & Verified'
        WHERE PurchaseRequestID = @PurchaseRequestID;

        COMMIT TRANSACTION;
        SELECT 'Purchase order verified successfully.' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.sp_ApplyVerifiedDeliveryStockIn
    @DeliveryID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @PurchaseOrderID INT,
        @PurchaseRequestID INT,
        @ItemID INT,
        @ReceivedQty DECIMAL(18,2),
        @PurchasingStatus NVARCHAR(60),
        @DeliveryStatus NVARCHAR(80),
        @BalanceAfter DECIMAL(18,2),
        @SourceRequisitionID INT;

    SELECT
        @PurchaseOrderID = PO.PurchaseOrderID,
        @PurchaseRequestID = PR.PurchaseRequestID,
        @ItemID = PR.ItemID,
        @ReceivedQty = D.ReceivedQty,
        @PurchasingStatus = PO.PurchasingStatus,
        @DeliveryStatus = D.DeliveryStatus,
        @SourceRequisitionID = PR.SourceRequisitionID
    FROM dbo.Deliveries D
    INNER JOIN dbo.PurchaseOrders PO ON D.PurchaseOrderID = PO.PurchaseOrderID
    INNER JOIN dbo.PurchaseRequests PR ON PO.PurchaseRequestID = PR.PurchaseRequestID
    WHERE D.DeliveryID = @DeliveryID;

    IF @PurchaseOrderID IS NULL THROW 50015, 'Delivery record not found.', 1;
    IF @PurchasingStatus <> 'Order Placed & Verified' THROW 50016, 'Purchasing verification has not passed.', 1;
    IF @DeliveryStatus <> 'Delivery Confirmed & Verified' THROW 50017, 'Delivery verification has not passed.', 1;
    IF @ReceivedQty IS NULL OR @ReceivedQty <= 0 THROW 50018, 'Invalid received quantity.', 1;

    IF EXISTS (SELECT 1 FROM dbo.InventoryTransactions WHERE ReferenceType = 'Delivery' AND ReferenceID = @DeliveryID AND TransactionType = 'Stock In')
    BEGIN
        RETURN;
    END;

    UPDATE dbo.Items SET CurrentStock = CurrentStock + @ReceivedQty WHERE ItemID = @ItemID;
    IF @@ROWCOUNT = 0 THROW 50019, 'Item associated with delivery was not found.', 1;

    SELECT @BalanceAfter = CurrentStock FROM dbo.Items WHERE ItemID = @ItemID;

    INSERT INTO dbo.InventoryTransactions (ItemID, TransactionType, Quantity, ReferenceType, ReferenceID, BalanceAfter, Notes)
    VALUES (@ItemID, 'Stock In', @ReceivedQty, 'Delivery', @DeliveryID, @BalanceAfter, 'Stock received after purchasing and delivery verification.');

    UPDATE dbo.PurchaseRequests SET PurchasingStatus = 'Closed' WHERE PurchaseRequestID = @PurchaseRequestID;

    IF @SourceRequisitionID IS NOT NULL
    BEGIN
        UPDATE dbo.Requisitions
        SET Status = 'Ready for Release'
        WHERE RequisitionID = @SourceRequisitionID AND Status = 'Awaiting Purchasing & Delivery';
    END;
END;
GO

CREATE PROCEDURE dbo.sp_VerifyDelivery
    @DeliveryID INT,
    @ReceivedQty DECIMAL(18,2),
    @InspectionNotes NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ReceivedQty <= 0 THROW 50020, 'Received quantity must be greater than zero.', 1;

        UPDATE dbo.Deliveries
        SET
            DeliveryStatus = 'Delivery Confirmed & Verified',
            ReceivedQty = @ReceivedQty,
            InspectionNotes = @InspectionNotes,
            UpdatedAt = SYSDATETIME()
        WHERE DeliveryID = @DeliveryID AND DeliveryStatus IN ('In Transit', 'Delivery Confirmed & Verified');

        IF @@ROWCOUNT = 0 THROW 50021, 'Delivery not found or cannot be verified.', 1;

        EXEC dbo.sp_ApplyVerifiedDeliveryStockIn @DeliveryID = @DeliveryID;

        COMMIT TRANSACTION;
        SELECT 'Delivery verification completed successfully.' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.sp_ReportDeliveryIssue
    @DeliveryID INT,
    @InspectionNotes NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Deliveries
    SET
        DeliveryStatus = 'Issue Reported - Refund/Replacement',
        InspectionNotes = @InspectionNotes,
        UpdatedAt = SYSDATETIME()
    WHERE DeliveryID = @DeliveryID AND DeliveryStatus <> 'Delivery Confirmed & Verified';

    IF @@ROWCOUNT = 0 THROW 50022, 'Delivery not found or already confirmed.', 1;

    SELECT 'Delivery issue recorded. No stock was added.' AS Message;
END;
GO

CREATE PROCEDURE dbo.sp_StockIn
    @ItemID INT,
    @Quantity DECIMAL(18,2),
    @Notes NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Quantity <= 0 THROW 50023, 'Quantity must be greater than zero.', 1;

        UPDATE dbo.Items WITH (UPDLOCK, ROWLOCK)
        SET CurrentStock = CurrentStock + @Quantity
        WHERE ItemID = @ItemID AND IsActive = 1;

        IF @@ROWCOUNT = 0 THROW 50024, 'Item not found or inactive.', 1;

        DECLARE @Balance DECIMAL(18,2);
        SELECT @Balance = CurrentStock FROM dbo.Items WHERE ItemID = @ItemID;

        INSERT INTO dbo.InventoryTransactions (ItemID, TransactionType, Quantity, ReferenceType, ReferenceID, BalanceAfter, Notes)
        VALUES (@ItemID, 'Stock In', @Quantity, 'Manual Adjustment', NULL, @Balance, @Notes);

        COMMIT TRANSACTION;
        SELECT @Balance AS CurrentStock, 'Stock In completed successfully.' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.sp_StockOut
    @RequisitionID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Requisitions WITH (UPDLOCK, HOLDLOCK) WHERE RequisitionID = @RequisitionID AND Status IN ('Approved', 'Ready for Release'))
        BEGIN
            THROW 50025, 'Requisition is not approved or ready for release.', 1;
        END;

        DECLARE @Required TABLE (ItemID INT PRIMARY KEY, RequiredQty DECIMAL(18,2));

        INSERT INTO @Required (ItemID, RequiredQty)
        SELECT ItemID, SUM(Quantity)
        FROM dbo.RequisitionItems
        WHERE RequisitionID = @RequisitionID
        GROUP BY ItemID;

        IF EXISTS (
            SELECT 1 FROM @Required R
            INNER JOIN dbo.Items I WITH (UPDLOCK, HOLDLOCK) ON R.ItemID = I.ItemID
            WHERE I.CurrentStock < R.RequiredQty
        )
        BEGIN
            THROW 50026, 'Insufficient stock. Stock Out cancelled.', 1;
        END;

        DECLARE @Balances TABLE (ItemID INT PRIMARY KEY, BalanceAfter DECIMAL(18,2));

        UPDATE I
        SET I.CurrentStock = I.CurrentStock - R.RequiredQty
        OUTPUT inserted.ItemID, inserted.CurrentStock INTO @Balances (ItemID, BalanceAfter)
        FROM dbo.Items I
        INNER JOIN @Required R ON I.ItemID = R.ItemID;

        INSERT INTO dbo.InventoryTransactions (ItemID, TransactionType, Quantity, ReferenceType, ReferenceID, BalanceAfter, Notes)
        SELECT R.ItemID, 'Stock Out', R.RequiredQty, 'Requisition', @RequisitionID, B.BalanceAfter, 'Materials released for approved requisition.'
        FROM @Required R
        INNER JOIN @Balances B ON R.ItemID = B.ItemID;

        UPDATE dbo.Requisitions
        SET Status = 'Completed'
        WHERE RequisitionID = @RequisitionID;

        COMMIT TRANSACTION;
        SELECT 'Stock Out completed. Requisition marked Completed.' AS Message;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.sp_GetItems
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ItemID, ItemCode, ItemName, Description, Unit, CurrentStock, MinimumStockLevel, UnitCost, IsActive
    FROM dbo.Items
    ORDER BY ItemID;
END;
GO

CREATE PROCEDURE dbo.sp_GetRequisitionDetails
    @RequisitionID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        R.RequisitionID, R.RequisitionNo, R.Department, R.RequestedBy, R.RequestDate, R.Status, R.PriorityNotes,
        RI.RequisitionItemID, I.ItemID, I.ItemCode, I.ItemName, RI.Quantity, I.Unit, I.UnitCost
    FROM dbo.Requisitions R
    LEFT JOIN dbo.RequisitionItems RI ON R.RequisitionID = RI.RequisitionID
    LEFT JOIN dbo.Items I ON RI.ItemID = I.ItemID
    WHERE R.RequisitionID = @RequisitionID
    ORDER BY RI.RequisitionItemID;
END;
GO

CREATE PROCEDURE dbo.sp_GetInventoryTransactions
    @ItemID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        T.InventoryTransactionID, T.ItemID, I.ItemCode, I.ItemName,
        T.TransactionType, T.Quantity, T.ReferenceType, T.ReferenceID,
        T.BalanceAfter, T.TransactionDate, T.Notes
    FROM dbo.InventoryTransactions T
    INNER JOIN dbo.Items I ON T.ItemID = I.ItemID
    WHERE @ItemID IS NULL OR T.ItemID = @ItemID
    ORDER BY T.TransactionDate DESC;
END;
GO