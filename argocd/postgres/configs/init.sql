-- PostgreSQL table schema for Vector logs
CREATE TABLE IF NOT EXISTS application_logs (
  id UUID PRIMARY KEY,
  timestamp TIMESTAMP WITH TIME ZONE,
  level VARCHAR(20),
  message TEXT,
  service VARCHAR(100),
  namespace VARCHAR(100),
  pod_name VARCHAR(255),
  pod_ip VARCHAR(45),
  node_name VARCHAR(255),
  environment VARCHAR(50),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON application_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_logs_level ON application_logs(level);
CREATE INDEX IF NOT EXISTS idx_logs_service ON application_logs(service);
CREATE INDEX IF NOT EXISTS idx_logs_pod_name ON application_logs(pod_name);
CREATE INDEX IF NOT EXISTS idx_logs_namespace ON application_logs(namespace);

-- Optional: Create a view for recent error logs
CREATE VIEW recent_error_logs AS
SELECT * FROM application_logs
WHERE level IN ('ERROR', 'FATAL')
  AND timestamp > NOW() - INTERVAL '24 hours'
ORDER BY timestamp DESC;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON TABLE application_logs TO vector_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO vector_user;