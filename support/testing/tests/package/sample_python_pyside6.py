import os


def qml_file(name):
    from PySide6.QtCore import QLibraryInfo
    qml_dir = QLibraryInfo.path(QLibraryInfo.LibraryPath.QmlImportsPath)
    return os.path.join(qml_dir, name)


# ALL_ESSENTIAL_MODULES
def test_python_pyside6_qt():
    from PySide6.QtCore import Qt
    enum = Qt.white
    assert(str(enum) == 'GlobalColor.white')


def test_python_pyside6_qtcore():
    from PySide6 import QtCore
    obj = QtCore.QObject()
    obj.setObjectName('MyObject')
    assert(obj.objectName() == 'MyObject')


def test_python_pyside6_qtgui():
    from PySide6 import QtGui
    color = QtGui.QColor.fromRgb(255, 255, 255, 255)
    assert(color.name(QtGui.QColor.HexArgb) == "#ffffffff")


def test_python_pyside6_qtwidgets():
    from PySide6 import QtWidgets
    app = QtWidgets.QApplication()
    label = QtWidgets.QLabel('Hello World')
    assert(label.text() == 'Hello World')
    QtWidgets.QApplication.shutdown(app)


def test_python_pyside6_qtprintsupport():
    from PySide6 import QtWidgets
    from PySide6 import QtPrintSupport
    app = QtWidgets.QApplication()
    p = QtPrintSupport.QPrinter()
    assert(p.creator() == '')
    QtWidgets.QApplication.shutdown(app)


def test_python_pyside6_qtsql():
    from PySide6 import QtSql
    db = QtSql.QSqlDatabase()
    assert(db.hostName() == '')


def test_python_pyside6_qtnetwork():
    from PySide6 import QtNetwork
    host_info = QtNetwork.QHostInfo()
    assert(host_info.localHostName() == 'buildroot')


def test_python_pyside6_qttest():
    from PySide6 import QtTest
    text = QtTest.QTest.toPrettyCString('hello there', 5)
    assert(text == '"hello"')


def test_python_pyside6_qtconcurrent():
    from PySide6 import QtConcurrent
    future = QtConcurrent.QFutureQString()
    assert(future.isRunning() is False)


# ALL_OPTIONAL_MODULES
def test_python_pyside6_qtdbus():
    from PySide6 import QtDBus
    message = QtDBus.QDBusMessage()
    assert(message.errorMessage() == '')


def test_python_pyside6_qtxml():
    from PySide6 import QtXml
    doc = QtXml.QDomDocument('temp.xml')
    assert(doc.toString() == '')


def test_python_pyside6_qtopengl():
    from PySide6 import QtOpenGL
    log = QtOpenGL.QOpenGLDebugLogger()
    assert(log.isLogging() is False)


def test_python_pyside6_qtopenglwidgets():
    from PySide6 import QtWidgets
    from PySide6 import QtOpenGLWidgets
    app = QtWidgets.QApplication()
    _ = QtOpenGLWidgets.QOpenGLWidget()
    # assert(widget.isValid() == False)
    # QOpenGLWidget is not supported on this platform.
    QtWidgets.QApplication.shutdown(app)


def test_python_pyside6_qtquickcontrols():
    from PySide6 import QtWidgets
    from PySide6 import QtQuick
    app = QtWidgets.QApplication()
    view = QtQuick.QQuickView()
    assert(str(view.status()) == 'Status.Null')
    view.setSource(qml_file('QtQuick/Controls/Universal/Label.qml'))
    assert(str(view.status()) == 'Status.Ready')
    view.close()
    QtWidgets.QApplication.shutdown(app)


def test_python_pyside6_qtquickwidgets():
    from PySide6 import QtWidgets
    from PySide6 import QtQuickWidgets
    app = QtWidgets.QApplication()
    view = QtQuickWidgets.QQuickWidget()
    assert(str(view.status()) == 'Status.Null')
    view.setSource(qml_file('QtQuick/Controls/Universal/Label.qml'))
    assert(str(view.status()) == 'Status.Ready')
    QtWidgets.QApplication.shutdown(app)


def test_python_pyside6_qtserialport():
    # The filepath used in this test does not need to exist. The serial port is never connected.
    from PySide6 import QtSerialPort
    ser = QtSerialPort.QSerialPort()
    ser.setPortName('/dev/tty')
    assert(ser.portName() == 'tty')


def test_python_pyside6_qtsvg():
    from PySide6 import QtSvg
    renderer = QtSvg.QSvgRenderer()
    renderer.setFramesPerSecond(30)
    assert(renderer.framesPerSecond() == 30)


def test_python_pyside6_qtsvgwidgets():
    from PySide6 import QtWidgets
    from PySide6 import QtSvgWidgets
    app = QtWidgets.QApplication()
    widget = QtSvgWidgets.QSvgWidget()
    widget.setObjectName('MyObject')
    assert(widget.objectName() == 'MyObject')
    QtWidgets.QApplication.shutdown(app)


if __name__ == "__main__":
    test_python_pyside6_qt()
    test_python_pyside6_qtcore()
    test_python_pyside6_qtgui()
    test_python_pyside6_qtwidgets()
    test_python_pyside6_qtprintsupport()
    test_python_pyside6_qtsql()
    test_python_pyside6_qtnetwork()
    test_python_pyside6_qttest()
    test_python_pyside6_qtconcurrent()
    test_python_pyside6_qtdbus()
    test_python_pyside6_qtxml()
    test_python_pyside6_qtopengl()
    test_python_pyside6_qtopenglwidgets()
    test_python_pyside6_qtquickcontrols()
    test_python_pyside6_qtquickwidgets()
    test_python_pyside6_qtserialport()
    test_python_pyside6_qtsvg()
    test_python_pyside6_qtsvgwidgets()
