-- CreateEnum
CREATE TYPE "RequestStatus" AS ENUM ('PENDING', 'SEARCHING', 'ACCEPTED', 'ARRIVING', 'IN_SERVICE', 'COMPLETED', 'CANCELLED');

-- CreateTable
CREATE TABLE "vehicles" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "manufacturer" TEXT NOT NULL,
    "model" TEXT NOT NULL,
    "plateNumber" TEXT NOT NULL,
    "year" TEXT,
    "color" TEXT,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "vehicles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "service_requests" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "providerId" TEXT,
    "category" "ProviderCategory" NOT NULL DEFAULT 'MECHANIC',
    "serviceType" TEXT NOT NULL,
    "problemDescription" TEXT NOT NULL,
    "status" "RequestStatus" NOT NULL DEFAULT 'PENDING',
    "customerLatitude" DOUBLE PRECISION NOT NULL,
    "customerLongitude" DOUBLE PRECISION NOT NULL,
    "customerAddress" TEXT,
    "vehicleId" TEXT,
    "vehiclePlate" TEXT NOT NULL,
    "vehicleModel" TEXT NOT NULL,
    "vehicleType" TEXT,
    "estimatedAmount" DOUBLE PRECISION,
    "finalAmount" DOUBLE PRECISION,
    "cancellationReason" TEXT,
    "acceptedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "service_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "service_requests_customerId_idx" ON "service_requests"("customerId");

-- CreateIndex
CREATE INDEX "service_requests_providerId_idx" ON "service_requests"("providerId");

-- CreateIndex
CREATE INDEX "service_requests_status_category_idx" ON "service_requests"("status", "category");

-- AddForeignKey
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_requests" ADD CONSTRAINT "service_requests_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_requests" ADD CONSTRAINT "service_requests_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_requests" ADD CONSTRAINT "service_requests_vehicleId_fkey" FOREIGN KEY ("vehicleId") REFERENCES "vehicles"("id") ON DELETE SET NULL ON UPDATE CASCADE;
