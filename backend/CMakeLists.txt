# CMakeList.txt : CMake project for backend, include source and define
# project specific logic here.
#
cmake_minimum_required (VERSION 3.8)

# Enable Hot Reload for MSVC compilers if supported.
if (POLICY CMP0141)
  cmake_policy(SET CMP0141 NEW)
  set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<IF:$<AND:$<C_COMPILER_ID:MSVC>,$<CXX_COMPILER_ID:MSVC>>,$<$<CONFIG:Debug,RelWithDebInfo>:EditAndContinue>,$<$<CONFIG:Debug,RelWithDebInfo>:ProgramDatabase>>")
endif()

project ("backend")

# Add source to this project's executable.
add_executable (backend "backend.cpp" "backend.h")

if (CMAKE_VERSION VERSION_GREATER 3.12)
  set_property(TARGET backend PROPERTY CXX_STANDARD 20)
endif()

find_package(Boost REQUIRED COMPONENTS system thread)
find_package(SQLite3 REQUIRED)

add_executable(backend 
    src/main.cpp 
    src/GameState.cpp 
    src/Grid.cpp 
    src/Entities.cpp 
    src/AI.cpp 
    src/WebSocketServer.cpp
    src/RestApi.cpp
    src/Database.cpp
)

target_include_directories(backend PRIVATE include)
target_link_libraries(backend Boost::system Boost::thread sqlite3)

