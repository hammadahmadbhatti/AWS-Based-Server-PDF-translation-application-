import React, { useState, useEffect } from 'react';
import { Amplify } from 'aws-amplify';
import { Authenticator } from '@aws-amplify/ui-react';
import '@aws-amplify/ui-react/styles.css';
import './App.css';

// Configure Amplify
Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId: process.env.REACT_APP_USER_POOL_ID,
      userPoolClientId: process.env.REACT_APP_USER_POOL_CLIENT_ID,
      region: process.env.REACT_APP_REGION || 'us-east-1',
    },
  },
});

const API_ENDPOINT = process.env.REACT_APP_API_ENDPOINT;

// Language options
const LANGUAGES = [
  { code: 'es', name: 'Spanish' },
  { code: 'fr', name: 'French' },
  { code: 'de', name: 'German' },
  { code: 'it', name: 'Italian' },
  { code: 'pt', name: 'Portuguese' },
  { code: 'zh', name: 'Chinese (Simplified)' },
  { code: 'zh-TW', name: 'Chinese (Traditional)' },
  { code: 'ja', name: 'Japanese' },
  { code: 'ko', name: 'Korean' },
  { code: 'ar', name: 'Arabic' },
  { code: 'hi', name: 'Hindi' },
  { code: 'ru', name: 'Russian' },
  { code: 'nl', name: 'Dutch' },
  { code: 'pl', name: 'Polish' },
  { code: 'sv', name: 'Swedish' },
  { code: 'tr', name: 'Turkish' },
  { code: 'vi', name: 'Vietnamese' },
  { code: 'th', name: 'Thai' },
  { code: 'id', name: 'Indonesian' },
  { code: 'el', name: 'Greek' },
];

function App() {
  return (
    <Authenticator>
      {({ signOut, user }) => (
        <MainApp user={user} signOut={signOut} />
      )}
    </Authenticator>
  );
}

function MainApp({ user, signOut }) {
  const [file, setFile] = useState(null);
  const [targetLanguage, setTargetLanguage] = useState('es');
  const [uploading, setUploading] = useState(false);
  const [jobs, setJobs] = useState([]);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [dragActive, setDragActive] = useState(false);

  // Fetch user's jobs on mount
  useEffect(() => {
    fetchJobs();
    const interval = setInterval(fetchJobs, 10000); // Poll every 10 seconds
    return () => clearInterval(interval);
  }, []);

  const getAuthToken = async () => {
    try {
      const { fetchAuthSession } = await import('aws-amplify/auth');
      const session = await fetchAuthSession();
      return session.tokens?.idToken?.toString();
    } catch (err) {
      console.error('Error getting auth token:', err);
      throw new Error('Authentication failed');
    }
  };

  const fetchJobs = async () => {
    try {
      const token = await getAuthToken();
      const response = await fetch(`${API_ENDPOINT}/jobs`, {
        headers: {
          // FIX: Added Bearer prefix to Authorization header
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch jobs');
      }

      const data = await response.json();
      setJobs(data.jobs || []);
    } catch (err) {
      console.error('Error fetching jobs:', err);
    }
  };

  const handleDrag = (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileSelect(e.dataTransfer.files[0]);
    }
  };

  const handleFileSelect = (selectedFile) => {
    setError(null);
    setSuccess(null);

    if (!selectedFile.name.toLowerCase().endsWith('.pdf')) {
      setError('Please select a PDF file');
      return;
    }

    if (selectedFile.size > 10 * 1024 * 1024) {
      setError('File size must be less than 10MB');
      return;
    }

    setFile(selectedFile);
  };

  const handleUpload = async () => {
    if (!file) {
      setError('Please select a file first');
      return;
    }

    setUploading(true);
    setError(null);
    setSuccess(null);

    try {
      const token = await getAuthToken();

      // Step 1: Get presigned URL
      const uploadResponse = await fetch(`${API_ENDPOINT}/upload`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          // FIX: Added Bearer prefix to Authorization header
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          filename: file.name,
          targetLanguage: targetLanguage,
          sourceLanguage: 'auto',
        }),
      });

      if (!uploadResponse.ok) {
        const errorData = await uploadResponse.json();
        throw new Error(errorData.error || 'Failed to get upload URL');
      }

      const { uploadUrl, jobId } = await uploadResponse.json();

      // Step 2: Upload file to S3
      const s3Response = await fetch(uploadUrl, {
        method: 'PUT',
        body: file,
        headers: {
          'Content-Type': 'application/pdf',
        },
      });

      if (!s3Response.ok) {
        throw new Error('Failed to upload file to S3');
      }

      setSuccess(`File uploaded successfully! Job ID: ${jobId}. Translation will start shortly.`);
      setFile(null);
      
      // Refresh jobs list
      setTimeout(fetchJobs, 2000);
    } catch (err) {
      console.error('Upload error:', err);
      setError(err.message || 'An error occurred during upload');
    } finally {
      setUploading(false);
    }
  };

  const getStatusBadgeClass = (status) => {
    switch (status) {
      case 'COMPLETED':
        return 'badge-success';
      case 'PROCESSING':
        return 'badge-processing';
      case 'FAILED':
        return 'badge-error';
      default:
        return 'badge-pending';
    }
  };

  const handleDownload = async (jobId) => {
    try {
      const token = await getAuthToken();
      const response = await fetch(`${API_ENDPOINT}/jobs/${jobId}`, {
        headers: {
          // FIX: Added Bearer prefix to Authorization header
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error('Failed to get download URL');
      }

      const job = await response.json();
      if (job.downloadUrl) {
        window.open(job.downloadUrl, '_blank');
      } else {
        setError('Download URL not available');
      }
    } catch (err) {
      console.error('Download error:', err);
      setError(err.message);
    }
  };

  return (
    <div className="app">
      <header className="header">
        <div className="header-content">
          {/* FIX: Removed corrupted emoji, using clean text or CSS icons */}
          <h1>
            <span className="header-icon" role="img" aria-label="document">📄</span>
            PDF Translator
          </h1>
          <div className="user-info">
            <span>Welcome, {user?.signInDetails?.loginId || 'User'}</span>
            <button onClick={signOut} className="btn-secondary">
              Sign Out
            </button>
          </div>
        </div>
      </header>

      <main className="main-content">
        <section className="upload-section">
          <h2>Upload PDF for Translation</h2>

          <div
            className={`dropzone ${dragActive ? 'active' : ''} ${file ? 'has-file' : ''}`}
            onDragEnter={handleDrag}
            onDragLeave={handleDrag}
            onDragOver={handleDrag}
            onDrop={handleDrop}
          >
            <input
              type="file"
              id="file-input"
              accept=".pdf"
              onChange={(e) => e.target.files[0] && handleFileSelect(e.target.files[0])}
              className="file-input"
            />
            <label htmlFor="file-input" className="dropzone-content">
              {file ? (
                <>
                  {/* FIX: Using proper emoji or text */}
                  <span className="file-icon" role="img" aria-label="file">📄</span>
                  <span className="file-name">{file.name}</span>
                  <span className="file-size">
                    ({(file.size / 1024 / 1024).toFixed(2)} MB)
                  </span>
                </>
              ) : (
                <>
                  {/* FIX: Using proper emoji or text */}
                  <span className="upload-icon" role="img" aria-label="upload">⬆️</span>
                  <span className="dropzone-text">
                    Drag and drop your PDF here, or click to select
                  </span>
                  <span className="dropzone-hint">Maximum file size: 10MB</span>
                </>
              )}
            </label>
          </div>

          <div className="options">
            <div className="form-group">
              <label htmlFor="language">Target Language:</label>
              <select
                id="language"
                value={targetLanguage}
                onChange={(e) => setTargetLanguage(e.target.value)}
                className="select-input"
              >
                {LANGUAGES.map((lang) => (
                  <option key={lang.code} value={lang.code}>
                    {lang.name}
                  </option>
                ))}
              </select>
            </div>

            <button
              onClick={handleUpload}
              disabled={!file || uploading}
              className="btn-primary"
            >
              {uploading ? (
                <>
                  <span className="spinner"></span>
                  Uploading...
                </>
              ) : (
                /* FIX: Using proper emoji */
                <>🚀 Translate</>
              )}
            </button>
          </div>

          {error && <div className="alert alert-error">{error}</div>}
          {success && <div className="alert alert-success">{success}</div>}
        </section>

        <section className="jobs-section">
          <h2>Your Translations</h2>

          {jobs.length === 0 ? (
            <div className="empty-state">
              {/* FIX: Using proper emoji */}
              <span className="empty-icon" role="img" aria-label="clipboard">📋</span>
              <p>No translations yet. Upload a PDF to get started!</p>
            </div>
          ) : (
            <div className="jobs-list">
              {jobs.map((job) => (
                <div key={job.jobId} className="job-card">
                  <div className="job-info">
                    <span className="job-filename">{job.filename}</span>
                    <span className="job-date">
                      {new Date(job.createdAt).toLocaleString()}
                    </span>
                    <span className="job-language">
                      → {LANGUAGES.find((l) => l.code === job.targetLanguage)?.name || job.targetLanguage}
                    </span>
                  </div>
                  <div className="job-actions">
                    <span className={`badge ${getStatusBadgeClass(job.status)}`}>
                      {job.status}
                    </span>
                    {job.status === 'COMPLETED' && (
                      <button
                        onClick={() => handleDownload(job.jobId)}
                        className="btn-download"
                      >
                        {/* FIX: Using proper emoji */}
                        ⬇️ Download
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      </main>

      <footer className="footer">
        <p>Powered by AWS Translate | © 2024 PDF Translator</p>
      </footer>
    </div>
  );
}

export default App;
