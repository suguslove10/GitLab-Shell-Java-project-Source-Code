package com.example;

import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import javax.servlet.RequestDispatcher;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import static org.mockito.Mockito.*;

public class MyServletTest {

    @Mock
    private HttpServletRequest request;

    @Mock
    private HttpServletResponse response;

    @Mock
    private RequestDispatcher requestDispatcher;

    private MyServlet servlet;

    @Before
    public void setUp() throws Exception {
        MockitoAnnotations.openMocks(this);
        servlet = new MyServlet();
        when(request.getRequestDispatcher("/index.jsp")).thenReturn(requestDispatcher);
    }

    @Test
    public void testDoGet() throws Exception {
        servlet.doGet(request, response);
        verify(request, times(1)).getRequestDispatcher("/index.jsp");
        verify(requestDispatcher, times(1)).forward(request, response);
    }
}
