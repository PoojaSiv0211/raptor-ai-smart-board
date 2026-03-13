# Backend Setup for File Repository

This Flask backend provides API endpoints for the file repository functionality in the Flutter app.

## Setup Instructions

### 1. Install Python Dependencies
```bash
pip install -r requirements.txt
```

### 2. Run the Backend Server
```bash
python backend.py
```

The server will start on `http://127.0.0.1:5000`

## API Endpoints

### Folders
- `GET /api/folders` - List all folders
- `POST /api/folders` - Create new folder
- `POST /api/delete-folder` - Delete folder

### Files
- `GET /api/files?folder=name` - List files in folder
- `POST /api/upload` - Upload PDF file
- `POST /api/delete` - Delete file
- `GET /api/open/<folder>/<filename>` - Serve PDF file

## Storage Structure
```
pdf_storage/
├── Default/
│   ├── file1.pdf
│   └── file2.pdf
├── Folder1/
│   └── document.pdf
└── Folder2/
    └── report.pdf
```

## Features
- **CORS enabled** for Flutter web app
- **File safety** - sanitizes file/folder names
- **Default folder** - automatically created
- **PDF only** - restricts uploads to PDF files
- **Error handling** - proper HTTP status codes

## Usage with Flutter App
1. Start the backend server: `python backend.py`
2. Run the Flutter app
3. Click "Books" button to open File Repository
4. The app will connect to `http://127.0.0.1:5000` for all file operations

## Development Notes
- Server runs in debug mode for development
- Files are stored in `pdf_storage/` directory
- Default folder cannot be deleted
- All file operations are logged to console