#pragma once

// روابط الخادم فقط. لا تضع مفاتيح حقيقية داخل المشروع أو ملف DEB.
#define GPSQ_API_BASE_URL @"https://key.p3nd.fun/api"
#define GPSQ_ACTIVATION_URL GPSQ_API_BASE_URL @"/activate.php"
#define GPSQ_HEALTH_URL GPSQ_API_BASE_URL @"/health.php"
#define GPSQ_APP_KEY_ENV_NAME @"GPSQ_APP_KEY"
