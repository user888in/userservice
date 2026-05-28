package com.devops.userservice.service;

import com.devops.userservice.dto.UserRequestDTO;
import com.devops.userservice.dto.UserResponseDTO;
import com.devops.userservice.exception.UserNotFoundException;
import com.devops.userservice.model.User;
import com.devops.userservice.repository.UserRepository;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.AssertionsForClassTypes.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
public class UserServiceTest {
    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserServiceImpl userService;

    @Test
    void createUser_success() {
        UserRequestDTO dto = new UserRequestDTO();
        dto.setName("mahesh");
        dto.setEmail("mahesh1@gmail.com");
        dto.setRole("ADMIN");
        User saved = User.builder().id(1L).name("mahesh").email("mahesh1@gmail.com").role("ADMIN").build();
        when(userRepository.existsByEmail(any())).thenReturn(false);
        when(userRepository.save(any())).thenReturn(saved);
        UserResponseDTO result = userService.createUser(dto);
        assertThat(result.getId()).isEqualTo(1L);
        assertThat(result.getEmail()).isEqualTo("mahesh1@gmail.com");
    }

    @Test
    void createUser_duplicateEmail_throwsException() {
        UserRequestDTO dto = new UserRequestDTO();
        dto.setEmail("dup@gmail.com");
        when(userRepository.existsByEmail("dup@gmail.com")).thenReturn(true);
        assertThrows(IllegalArgumentException.class, () -> userService.createUser(dto));
    }
    @Test
    void getUserById_notFound_throwsException() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());
        assertThrows(UserNotFoundException.class, () -> userService.getUserById(99L));
    }

}
