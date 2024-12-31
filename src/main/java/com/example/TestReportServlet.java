package com.example;

import java.io.*;
import javax.servlet.*;
import javax.servlet.http.*;
import javax.servlet.annotation.WebServlet;

@WebServlet("/junit.xml")
public class TestReportServlet extends HttpServlet {
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String reportFileName = getServletContext().getRealPath("/WEB-INF/junit/junit.xml");
        File reportFile = new File(reportFileName);

        response.setContentType("text/xml");
        PrintWriter out = response.getWriter();

        if (reportFile.exists()) {
            try (BufferedReader br = new BufferedReader(new FileReader(reportFile))) {
                String line;
                while ((line = br.readLine()) != null) {
                    out.println(line);
                }
            }
        } else {
            out.println("<error>junit.xml not found</error>");
        }
    }
}