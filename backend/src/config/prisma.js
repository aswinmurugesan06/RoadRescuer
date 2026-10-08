let prisma = null;

try {
  const { PrismaClient } = require('@prisma/client');
  prisma = new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
  });
} catch (error) {
  // Prisma client not yet generated via 'prisma generate'
  prisma = null;
}

/**
 * Checks whether PostgreSQL connection is alive.
 * @returns {Promise<{connected: boolean, message: string}>}
 */
async function checkDatabaseConnection() {
  if (!prisma) {
    return {
      connected: false,
      message: 'Prisma Client not initialized. Run "prisma generate" after installing Prisma CLI.',
    };
  }

  try {
    await Promise.race([
      prisma.$queryRaw`SELECT 1`,
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Connection timed out')), 3000)
      ),
    ]);
    return {
      connected: true,
      message: 'PostgreSQL database connected successfully',
    };
  } catch (error) {
    return {
      connected: false,
      message: `Database connection failed: ${error.message}`,
    };
  }
}

module.exports = {
  prisma,
  checkDatabaseConnection,
};
