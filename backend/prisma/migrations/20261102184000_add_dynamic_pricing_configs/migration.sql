-- AlterTable
ALTER TABLE "service_requests" ADD COLUMN     "estimateBreakdown" JSONB,
ADD COLUMN     "pricingConfigId" TEXT,
ADD COLUMN     "revisedEstimateBreakdown" JSONB;

-- CreateTable
CREATE TABLE "pricing_configs" (
    "id" TEXT NOT NULL,
    "category" "ProviderCategory" NOT NULL,
    "problemCategory" TEXT,
    "vehicleType" TEXT,
    "baseLaborCharge" DECIMAL(10,2) NOT NULL,
    "perKmCharge" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "includedDistanceKm" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "additionalCharges" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "taxRate" DECIMAL(5,4) NOT NULL DEFAULT 0.18,
    "description" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "pricing_configs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "pricing_configs_category_vehicleType_isActive_idx" ON "pricing_configs"("category", "vehicleType", "isActive");

-- CreateIndex
CREATE INDEX "pricing_configs_category_problemCategory_vehicleType_isActi_idx" ON "pricing_configs"("category", "problemCategory", "vehicleType", "isActive");

-- CreateUniqueIndex: Partial unique index to prevent duplicate active rules for same category + problem + vehicle
CREATE UNIQUE INDEX "idx_unique_active_pricing_rule" ON "pricing_configs" (
    "category",
    COALESCE("problemCategory", '__ALL__'),
    COALESCE("vehicleType", '__ALL__')
) WHERE "isActive" = true;

-- AddForeignKey
ALTER TABLE "service_requests" ADD CONSTRAINT "service_requests_pricingConfigId_fkey" FOREIGN KEY ("pricingConfigId") REFERENCES "pricing_configs"("id") ON DELETE SET NULL ON UPDATE CASCADE;
