package com.omniplay.auth;

import org.springframework.data.jpa.repository.JpaRepository;

public interface AuthRefreshHistoryRepository extends JpaRepository<AuthRefreshHistory, AuthRefreshHistoryId> {}
