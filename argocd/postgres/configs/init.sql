CREATE TABLE IF NOT EXISTS application_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON application_logs(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_logs_level ON application_logs(level);
CREATE INDEX IF NOT EXISTS idx_logs_service ON application_logs(service);
CREATE INDEX IF NOT EXISTS idx_logs_pod_name ON application_logs(pod_name);
CREATE INDEX IF NOT EXISTS idx_logs_namespace ON application_logs(namespace);

-- Create user action
CREATE TABLE IF NOT EXISTS user_action (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  timestamp TIMESTAMP WITH TIME ZONE,
  level VARCHAR(20),
  message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_user_action_timestamp ON user_action(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_user_action_level ON user_action(level);

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON TABLE application_logs TO vector_user;
GRANT ALL PRIVILEGES ON TABLE user_action TO vector_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO vector_user;